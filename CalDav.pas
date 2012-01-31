namespace RemObjects.Calendar;

interface

uses
  RemObjects.Calendar.Calendar,
  System.Collections.Generic,
  System.Globalization,
  System.Runtime.InteropServices,
  System.Text,
  System.Linq, 
  System.Xml.Linq,
  DDay.iCal,
  DDay.iCal.Serialization.iCalendar,
  Kayak.Http;

type
  CalDavRequest = public class(DavController)
  private
    method GenerateFor(aInput: PropFindRequest; aCalendar: Calendars; aTarget: DavResponses);
    method ParseDate(aValue: string): nullable DateTime;
    method AddData(aResp: DavResponses; aEntry: Events; aPath: String; aProperties: sequence of Xelement; aValidator: Func<IEvent, Boolean> := nil);
    method GenerateCalendarDataEntry(aInput: PropFindRequest; aCalendar: Calendars; aTarget: DavResponses; aEntry: Events);
    method IntPropFind(aOwner: DavController; aInput: PropFindRequest);
    method IntDelete(aOwner: DavController);
    method IntMove(aOwner: DavController);
    method IntPut(aOwner: DavController; aInput: System.IO.MemoryStream);
    method IntOptions(aOwner: DavController);
    method IntGet(aOwner: DavController);
    method IntReport(aOwner: DavController; aRoot: ReportRequest);
    method IntPropPatch(aOwner: DavController; aRoot: ReportRequest);
  protected
  public
    constructor(aPath: string);
  end;

implementation

constructor CalDavRequest(aPath: string);
begin
  inherited constructor(aPath);
  PropFind += IntPropFind;
  Move += IntMove;
  Options += IntOptions;
  Put += IntPut;
  Delete += IntDelete;  
  Get += IntGet;  
  Report += IntReport;
  PropPatch += IntPropPatch;
end;

method CalDavRequest.IntPropFind(aOwner: DavController; aInput: PropFindRequest);
begin
  var lOutput := new DavResponses;

  if (aOwner.Calendar <> nil) and (not String.IsNullOrEmpty(aOwner.Document)) then  begin
    var lItem := aOwner.Controller.Events(aOwner.Calendar).FirstOrDefault(a->a.ICSName = aOwner.Document);
    if lItem = nil then begin
      var lItemD := new DavResponse();
      lOutput.Add(lItemD);
      lItemD.Status := 'HTTP/1.1 404 Not Found';
      lItemD.HREF := [Request.Path];
    end else begin
      GenerateCalendarDataEntry(aInput, aOwner.Calendar, lOutput, lItem);
    end;
  end else begin
    GenerateFor(aInput,aOwner .Calendar, lOutput);
    if (aOwner .Calendar <> nil) and (aInput.Depth > DavDepth.Zero)  then begin
      for each el in aOwner.Controller.Events(aOwner.Calendar).ToArray do
        GenerateCalendarDataEntry(aInput, aOwner.Calendar, lOutput, el);
    end;
    if (aOwner.Calendar = nil) and (aInput.Depth > DavDepth.Zero) then begin
     for each en in Controller.Calendars do begin
      GenerateFor(aInput,en , lOutput);
      if aInput.Depth > DavDepth.Infinity then begin
        for each el in aOwner.Controller.Events(en).ToArray do
          GenerateCalendarDataEntry(aInput, en, lOutput, el);
      end;
     end;
    end;
  end;


  SendPropFindResponse(lOutput);
end;

method CalDavRequest.IntDelete(aOwner: DavController);
begin
  if (aOwner.Calendar <> nil) and(aOwner.Document <> nil) then begin
    var lItem := aOwner.Controller.Events(aOwner.Calendar).FirstOrDefault(a->a.ICSName = aOwner.Document);
    if lItem = nil then begin
      Send404();
      exit;
    end else begin
      aOwner.Controller.LDA.DeleteRow(lItem);
      aOwner.Calendar.CTag := 'g'+Guid.NewGuid.ToString('D');
      aOwner.Controller.LDA.UpdateRow(aOwner.Calendar);
      aOwner.Controller.LDA.ApplyChanges;
    end;
  end;
  SendDeleteResponse('204 No Content');
end;

method CalDavRequest.IntPut(aOwner: DavController; aInput: System.IO.MemoryStream);
begin
  if (aOwner.Calendar = nil) or sTring.IsNullOrEmpty(aOwner.Document) then begin
    Send404;
    exit;
  end;

  try
    var lAlarms: array of Alarms; 
    var lRecurs: array of Recurrences;
    var lEvent := iCalendarUtils.StreamToEvent(aInput, out lAlarms, out lRecurs);
    lEvent.ETag := Guid.NewGuid.ToString('D');

    var lItem := aOwner.Controller.Events(aOwner.Calendar).FirstOrDefault(a->a.ICSName = aOwner.Document);
    lEvent.CalendarID := aOwner.Calendar.ID;
    lEvent.LastUpdated := DateTime.UtcNow;
    lEvent.ICSName := aOwner.Document;
    if lItem = nil then begin
      if lEvent.Created < new Datetime(1970, 1, 1)  then 
        lEvent.Created := lEvent.LastUpdated;
      aOwner.Controller.LDA.InsertRow(lEvent)
    end else begin
      lEvent.ID := lItem.ID;
      lEvent.Created := lItem.LastUpdated;
      if lEvent.Created < new Datetime(1970, 1, 1)  then 
        lEvent.Created := lEvent.LastUpdated;
      var lItems := aOwner.Controller.LDA.Execute([aOwner.Controller.LDA.GetTable<Alarms>().Where(a->a.EventID = lItem.ID), aOwner.Controller.LDA.GetTable<Recurrences>().Where(a->a.EventID = lItem.ID)]);
      for each el in IEnumerable<Alarms>(lItems[0])  do aOwner.Controller.LDA.DeleteRow(el);
      for each el in IEnumerable<Recurrences>(lItems[1])  do aOwner.Controller.LDA.DeleteRow(el);
      aOwner.Controller.LDA.UpdateRow(lItem, lEvent);
    end;
    aOwner.Calendar.CTag := 'g'+Guid.NewGuid.ToString('D');
    aOwner.Controller.LDA.UpdateRow(aOwner.Calendar);
    aOwner.Controller.LDA.ApplyChanges;
    for each el in lAlarms do begin el.EventID := lEvent.id; aOwner.Controller.LDA.InsertRow(el); end;
    for each el in lRecurs do begin el.EventID := lEvent.id; aOwner.Controller.LDA.InsertRow(el); end;
    aOwner.Controller.LDA.ApplyChanges;
    SendPutResponse(lItem <> nil, lEvent.ETag);
    exit;
  except on e: Exception do begin
    SendInternalError(e.ToString);
    exit;
    end;
  end;

  Send404;
end;

method CalDavRequest.IntOptions(aOwner: DavController);
begin
  SendOptionsResponse(['GET', 'HEAD', 'POST', 'OPTIONS', 'DELETE', 'PUT', 'PROPFIND', 'SEARCH', 'REPORT']);
end;

method CalDavRequest.IntGet(aOwner: DavController);
begin
  if (aOwner.Calendar <> nil) and(aOwner.Document <> nil) then begin
    var lItem := aOwner.Controller.Events(aOwner.Calendar).FirstOrDefault(a->a.ICSName = aOwner.Document);
    if lItem = nil then begin
      Send404();
      exit;
    end else begin
      var responseBody := iCalendarUtils.ICalendarToString(lItem, Controller.LDA);
      headers.Status := "200 OK";
      headers.Headers.Add('Content-Type', 'text/calendar');
      headers.Headers.Add('Content-Length', responseBody.Length.ToSTring);
      var lBody := new BufferedProducer(responseBody);

      response.OnResponse(headers, lBody);
      exit;
    end;
  end;

  var responseBody := "<html>
   <head><title>Welcome</title></head>
  <body>
    <h1>Not Allowed</h1>
    This directory is not meant to be accessed through a web browser. Use a CALDAV client like Thunderbird or iCalendar.

end;
  </body>
</html>";
    var headers := new HttpResponseHead(
        Status := "405 Method Not Allowed",
        Headers := new Dictionary<string, string>
    );
    headers.Headers.Add('Content-Type', 'text/html');
    headers.Headers.Add('Content-Length', responseBody.Length.ToSTring);
    var lBody := new BufferedProducer(responseBody);

  if aOwner.Request.Method = 'HEAD' then lBody := nil;
  response.OnResponse(headers, lBody);
end;

method CalDavRequest.GenerateFor(aInput: PropFindRequest; aCalendar: Calendars; aTarget: DavResponses);
begin

  var lItem := new DavResponse;
  aTarget.Add(lItem);
  lItem.HREF := [if aCalendar =nil then RootPath else RootPath+aCalendar.Name+'/'];
  for each el in aInput.Properties do begin
    var lFail := false;
    case el.Name.ToString of
      '{DAV:}principal-URL': lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}principal-URL',new  XElement('{DAV:}href', RootPath)));
      '{DAV:}resourcetype': lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}resourcetype', 
        new XElement('{DAV:}collection'), 
        if aCalendar <> nil then new XElement('{urn:ietf:params:xml:ns:caldav}calendar') else nil
        ));
      '{DAV:}owner': lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}owner', new Xelement('{DAV:}href', RootPath+Auth.Username+'/')));
      '{urn:ietf:params:xml:ns:caldav}calendar-user-address-set':
        lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{urn:ietf:params:xml:ns:caldav}calendar-user-address-set', new XElement('{DAV:}href', RootPath+if aCalendar = nil then '' else calendar.Name+'/')));
      '{urn:ietf:params:xml:ns:caldav}calendar-home-set':
        lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{urn:ietf:params:xml:ns:caldav}calendar-home-set', new XElement('{DAV:}href', RootPath+if aCalendar = nil then '' else calendar.Name+'/')));
      //'{urn:ietf:params:xml:ns:caldav}calendar-user-address-set'
      '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set': begin
        lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set', 
          new XElement('{urn:ietf:params:xml:ns:caldav}comp', new XAttribute('name', 'VEVENT'))
         ));
      end;
      '{DAV:}principal-collection-set': lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}principal-collection-set',new  XElement('{DAV:}href', RootPath)));
      '{DAV:}supported-report-set':
        lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}supported-report-set',
          new XElement('{DAV:}supported-report', new XElement('{DAV:}report', new XElement('{urn:inverse:params:xml:ns:inverse-dav}collection-query'))),
          new XElement('{DAV:}supported-report', new XElement('{DAV:}report', new XElement('{DAV:}expand-property')))
        ));
      '{DAV:}getcontenttype': if acalendar <> nil then lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}getcontenttype','text/calendar')) else 
        lItem.GetPropStatWithStatus('HTTP/1.1 404 Not Found').Prop.Add(new XElement(el.Name));
      //'{DAV:}getetag': 
      '{http://calendarserver.org/ns/}getctag': 
        lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{http://calendarserver.org/ns/}getctag', if aCalendar = nil then '' else aCalendar.cTag));
      '{DAV:}displayname':
        lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}displayname', if aCalendar = nil then 'RemObjects Calendar Server' else aCalendar.DisplayName));
      '{urn:ietf:params:xml:ns:caldav}calendar-description':
      if aCalendar = nil then lFail := true else 
        lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{urn:ietf:params:xml:ns:caldav}calendar-description', aCalendar.Description));
      '{http://apple.com/ns/ical/}calendar-color':
      if aCalendar = nil then lFail := true else 
        lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{http://apple.com/ns/ical/}calendar-color', aCalendar.Color));
      '{http://apple.com/ns/ical/}calendar-order':
      if aCalendar = nil then lFail := true else 
        lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{http://apple.com/ns/ical/}calendar-order', aCalendar.Order));
      //'{http://apple.com/ns/ical/}calendar-order':
      //if aCalendar = nil then lFail := true else 
        //lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{http://apple.com/ns/ical/}calendar-order', aCalendar.Order));
    else 
      lFAil := true;
    end;
    if lFail then       lItem.GetPropStatWithStatus('HTTP/1.1 404 Not Found').Prop.Add(new XElement(el.Name));
  end;
end;

method CalDavRequest.GenerateCalendarDataEntry(aInput: PropFindRequest; aCalendar: Calendars; aTarget: DavResponses; aEntry: Events);
begin
  var lItem := new DavResponse;
  aTarget.Add(lItem);
  lItem.HREF := [RootPath+aCalendar.Name+'/'+aEntry.ICSName];
  for each el in aInput.Properties do begin
    var lFail := false;
    case el.Name.ToString of
      '{DAV:}principal-URL': lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}principal-URL',new  XElement('{DAV:}href', RootPath)));
      '{DAV:}resourcetype': lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}resourcetype'));
      '{DAV:}owner': lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}owner', new Xelement('{DAV:}href', RootPath+Auth.Username+'/')));
      '{DAV:}getcontenttype': lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}getcontenttype','text/calendar'));
      '{DAV:}getetag': lItem.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}getetag','"'+aEntry.ETag+'"'));
    else 
      lFAil := true;
    end;
    if lFail then       lItem.GetPropStatWithStatus('HTTP/1.1 404 Not Found').Prop.Add(new XElement(el.Name));
  end;
end;

method CalDavRequest.IntReport(aOwner: DavController; aRoot: ReportRequest);
begin
  ConsoleApp.Logger.Info('Processing: '+aRoot.RootRequest.Name.ToString);
  case aRoot.RootRequest.Name.ToString of 
    '{DAV:}principal-search-property-set':
      begin
        SendXmlResponse('207 Multi-Status',
          new XDocument(new XElement('principal-search-property-set', //new XAttribute(XNamespace.Xmlns+'d', 'DAV:'), 
          //new XAttribute(XNamespace.Xmlns+'a', 'urn:ietf:params:xml:ns:caldav'),
          //new XAttribute(XNamespace.Xmlns+'b', 'http://calendarserver.org/ns/'),

          new XElement('{DAV:}principal-search-property', new XElement('{DAV:}prop', new XElement('{urn:ietf:params:xml:ns:caldav}calendar-user-type'))
          , new XElement('{DAV:}description', 'Calendar User Type')),

          new XElement('{DAV:}principal-search-property', new XElement('{DAV:}prop', new XElement('{urn:ietf:params:xml:ns:caldav}calendar-user-address-set'))
        , new XElement('{DAV:}description', 'Calendar User Address Set')),

          new XElement('{DAV:}principal-search-property', new XElement('{DAV:}prop', new XElement('{urn:ietf:params:xml:ns:caldav}displayname'))
        , new XElement('{DAV:}description', 'Display name'))
         )));
      end;

      '{urn:ietf:params:xml:ns:caldav}calendar-query': begin
        if Calendar = nil then begin
          Send404;
          exit;
        end;

        var lProperties := aRoot.RootRequest.Element('{DAV:}prop'):Elements;

        var lMultiReq := new DavResponses;

        var lTimeStart: Nullable DateTime := nil;
        var lTimeEnd: Nullable DateTime := nil;
        
        var lTable := Controller.Events(Calendar);
        var lFilter := aRoot.RootRequest.Element('{urn:ietf:params:xml:ns:caldav}filter');
        if assigned(lFilter) then begin
          var lTimeFilter := lFilter.Descendants('{urn:ietf:params:xml:ns:caldav}time-range'):FirstOrDefault;
          if lTimeFilter <> nil then begin
            lTimeStart := ParseDate(lTimeFilter.Attribute('start'):Value);
            lTimeEnd := ParseDate(lTimeFilter.Attribute('end'):Value);
          end;
        end;

        var lRoot := RootPath+Calendar.Name+'/';
        for each el in lTable do begin
          var lVal := el.ICSName;
          AddData(lMultiReq, el, lRoot+lVal, lProperties, a-> begin
            if a.RecurrenceRules.Count > 0 then begin
              exit true;
            end;

            if lTimeStart <> nil then begin
              if a.Start.UTC <= DateTime(lTimeStart) then exit false;
            end;
            if lTimeEnd <> nil then begin
              if a.End.UTC >= DateTime(lTimeEnd) then exit false;
            end;

            exit true;
          end);
        end;
        SendXmlResponse('207 Multi-Status', new XDocument(lMultiReq.ToXElement));
      end;

      '{urn:ietf:params:xml:ns:caldav}calendar-multiget': begin
        if Calendar = nil then begin
          Send404;
          exit;
        end;

        var lProperties := aRoot.RootRequest.Element('{DAV:}prop'):Elements;

        var lURls := aRoot.RootRequest.Elements('{DAV:}href');
        var lMultiReq := new DavResponses;
        
        var lTable := Controller.Events(Calendar);
          var lRoot := RootPath+Calendar.Name+'/';
        for each el in lUrls do begin
          var lVal := el.Value;
          if not lVal.StartsWith(lRoot) then  continue;
          lVal := lVal.Substring(lRoot.Length);
          var lEntry := lTable.FirstOrDefault(a->a.ICSName = lVal);
          if lEntry = nil then begin
            lMultiReq.GetOrAdd('HTTP/1.1 404 Not Found', lRoot+lVal);
          end else begin
            AddData(lMultiReq, lEntry, lRoot+lVal, lProperties);
          end;
        end;
        SendXmlResponse('207 Multi-Status', new XDocument(lMultiReq.ToXElement));
      end
    else
      Send404;
  end;
end;

method CalDavRequest.AddData(aResp: DavResponses; aEntry: Events; aPath: String; aProperties: sequence of Xelement; aValidator: Func<IEvent, Boolean> := nil);
begin
  var lCalendar := new iCalendar;
  lCalendar.ProductID := '-//remobjects.com//NONSGML Calendar v1.0//EN';
  var lRealCal := iCalendarUtils.ICalenderToEvent(aEntry, Controller.LDA, lCalendar);
  if aValidator <> nil then begin
    if not aValidator(lRealCal) then exit;
  end;
  lCalendar.Events.Add(lRealCal);
  var lDT := aResp.GetOrAdd('', aPath);

  var lSer := new iCalendarSerializer;
  var lCal :=lSer.SerializeToString(lCalendar);

  for each elem in aProperties do begin
    case elem.Name.ToString of
      '{DAV:}getetag': begin
        lDT.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{DAV:}getetag', '"'+aEntry.ETag+'"'));
      end;

      '{urn:ietf:params:xml:ns:caldav}calendar-data': begin
        lDT.GetPropStatWithStatus('HTTP/1.1 200 OK').Prop.Add(new XElement('{urn:ietf:params:xml:ns:caldav}calendar-data', lCal));
      end;
      '{urn:ietf:params:xml:ns:caldav}schedule-tag': ;
    else
      lDT.GetPropStatWithStatus('HTTP/1.1 404 Not Found').Prop.Add(elem);
    end;
  end;
end;

method CalDavRequest.ParseDate(aValue: string): nullable DateTime;
begin
  if aValue = nil then exit nil;
  var d: DateTime;
  if DateTime.TryParseExact(aValue,   'yyyyMMdd\THHmmss\Z', System.Globalization.DateTimeFormatInfo.InvariantInfo, DateTimeStyles.AssumeUniversal or DateTimeStyles.AllowWhiteSpaces, out d) then exit d;
  exit nil;
end;

method CalDavRequest.IntPropPatch(aOwner: DavController; aRoot: ReportRequest);
begin
  var lMultiReq := new DavResponses;
  SendXmlResponse('207 Multi-Status', new XDocument(lMultiReq.ToXElement));
//  SendForbidden;
end;

method CalDavRequest.IntMove(aOwner: DavController);
begin
  if (aOwner.Calendar <> nil) and(aOwner.Document <> nil) then begin
    var lItem := aOwner.Controller.Events(aOwner.Calendar).FirstOrDefault(a->a.ICSName = aOwner.Document);
    var lDest: String := nil;
    var lPrepend: string := '';
    aowner.Request.Headers.TryGetValue('Destination', out lDest) ;
    if (lItem = nil) or STring.IsNullOrEmpty(lDest) then begin
      Send404();
      exit;
    end;
    if (lDest.StartsWith('http://', StringComparison.InvariantCultureIgnoreCase) or 
      lDest.StartsWith('https://', StringComparison.InvariantCultureIgnoreCase)) and (lDest.IndexOf('/', 9) > 0) then begin
      lPrepend := lDEst.Substring(0, lDest.IndexOf('/', 9));
      lDest := lDest.Substring(lPrepend.Length);
    end;
    ConsoleApp.Logger.Info('Moving '+aOwner.Document +' from '+aOwner.Calendar.Name+ ' to '+lDest);
    if not ldest.StartsWith(RootPath) then begin
      SendForbidden();
      exit;
    end;
    lDest := lDest.Substring(RootPath.Length);
    while lDest.StartsWith('/') do lDest := lDest.Substring(1);
    if (lDest.IndexOf('/') = -1) or (lDest.IndexOf('/') <> lDest.LastIndexOf('/')) then begin
      SendForbidden();
      exit;
    end;
    var lVal := lDest.Substring(0, lDest.IndexOf('/'));
    var lCal2 := aOwner.Controller.Calendars.FirstOrDefault(a->a.Name = lVal);
    lDest := lDest.Substring(lDest.IndexOf('/')+1).Trim;
    if String.IsNullOrEmpty(lDest) or (lCal2 = nil) then begin
      SendForbidden();
      exit;
    end;
    try
      var lDoc := aOwner.Controller.Events(lCal2).FirstOrDefault(a->a.ICSName = lDest);
      if lDoc <> nil then begin
        aOwner.Controller.LDA.DeleteRow(lDoc);
        aOwner.Controller.LDA.ApplyChanges;
      end;
      lItem.CalendarID := lCal2.ID;
      lItem.ETag := Guid.NewGuid.ToString('D');
      aOwner.Controller.LDA.UpdateRow(lItem);
      lCal2.CTag := Guid.NewGuid.ToString('D');
      CAlendar.CTag := Guid.NewGuid.ToString('D');
      aOwner.Controller.LDA.UpdateRow(lCAl2);
      aOwner.Controller.LDA.UpdateRow(Calendar);
      aOwner.Controller.LDA.ApplyChanges;
      SendMoveResponse(lDoc = nil, lPrepend+RootPath+lCAl2.Name+'/'+lItem.ICSName,lItem.ETag);
    except
      on e: Exception do begin
        SendInternalError(e.Message);
      end;
    end;
  end else
    Send404;
end;


end.
