namespace RemObjects.Calendar;

interface

uses
  RemObjects.Calendar.Calendar,
  System.Collections.Generic,
  System.IO,
  System.Linq,
  System.Text, 
  System.Xml.Linq, 
  Kayak.Http;

type
  DavController = public abstract class(RequestHandler, IHttpResponseDelegate, IDisposable)
  private
    fIntResponse: IHttpResponseDelegate;
    fController: CalendarController;
    fRootPath: string;

    method OnResponse(head: HttpResponseHead; body: Kayak.IDataProducer);
  protected
    method ParsePropPatch(aDepth: DavDepth; aDav: array of String);
    method ParsePropFind(adepth: DavDepth; aDav: array of string);
    method ParseReport(adepth: DavDepth; aDav: array of string);
    method ParseOptions(adepth: DavDepth; aDav: array of string);
    method ParsePut(adepth: DavDepth; aDav: array of string);
    method ParseDelete(aDepth: DavDepth; aDav: array of string);
    method ParseMove(aDepth: DavDepth; aDav: array of string);
  public
    //class method CleanXmlns(el: XElement);
    constructor(aPath: string);
    property RootPath: string read fRootPath;
    method Dispose;
    property Controller: CalendarController read fController;
    property Calendar: Calendars;
    property Document: string;
    property Response: IHttpResponseDelegate read self write fIntResponse; override;
    //property Calendar: 
    method DoRequest; override;
    method SendPropFindResponse(aResp: DavResponses);
    method SendOptionsResponse(aDavAllow: array of String);
    method SendPutResponse(aUpdated: Boolean; aTag: string);
    method SendMoveResponse(aNew: Boolean; aLoc, eTag: string);
    method SendDeleteResponse(aStatus: string);
    const 
      DeleteStatusOk = '204 No Content';
      DeleteStatusNotFound = '404 Not Found';
      DeleteStatusNoAccess = '403 Forbidden';

    event PropFind: Action<DavController, PropFindRequest>;
    event Options: Action<DavController>;
    event Put: Action<DavController, MemoryStream>;
    event Delete: Action<DavController>;
    event Move: Action<DavController>;
    event Get: Action<DavController>;
    event Report: Action<DavController, ReportRequest>;
    event PropPatch: Action<DavController, ReportRequest>;
  end;
  DavDepth = public (Zero, One, Infinity);

  ReportRequest = public class(DavRequest)
  private
  public
    property RootRequest: XElement;
  end;


  DavRequest = public class
  public
    property Depth: DavDepth;
    property Dav: array of String;
  end;

  PropFindMode = public enum (AllProp, PropName, Prop);
  PropFindRequest = public class(DavRequest)
  private
  public
    property Mode: PropFindMode;
    property Properties: array of XElement;
  end;

  DavResponses = public class(List<DavResponse>)
  private
  public
    method ToXElement: XElement;
    method GetOrAdd(aStatus: string; aHREF: string): DavResponse;
  end;
  DavResponse = public class
  private
  public
    property SynchResponse: Boolean;
    property HREF: array of string;
    property Status: string;
    property PropStat: List<DavPropStat> := new List<DavPropStat>; readonly;
    property Error: XElement;
    property ResponseDescription: string;
    property Location: string;

    method ToXElement: XElement;

    method GetPropStatWithStatus(aStatus: string): DavPropStat;
  end;
  DavPropStat = public class
  private
  public
    property Prop: XElement;
    property Status: string;
    property Error: XElement;
    property ResponseDescription: string;
    method ToXElement: XElement;
  end;

implementation

method DavResponses.ToXElement: XElement;
begin
  exit new XElement('{DAV:}multistatus', // new XAttribute(XNamespace.Xmlns+'D', 'DAV:'), 
  self.Select(a->a.ToXElement));
end;

method DavResponses.GetOrAdd(aStatus: string; aHREF: string): DavResponse;
begin
  for each el in self do begin
    if (el.Status = aStatus) and (Length(el.HREF)  = 1) and (el.HREF[0] = aHREF) then exit el;
  end;
  var lItem := new DavResponse(Status := aStatus, HREF := [aHREF]);
  add(lItem);
  exit lItem;
end;

method DavPropStat.ToXElement: XElement;
begin
  exit new XElement('{DAV:}propstat', Prop, if String.IsNullOrEmpty(Status) then nil else new XElement('{DAV:}status', Status), Error, 
    if ResponseDescription = nil then nil else new XElement('{DAV:}responsedescription', ResponseDescription));
end;

method DavResponse.ToXElement: XElement;
begin
  exit new XElement(if SynchResponse then '{DAV:}synch-response' else '{DAV:}response', HRef.Select(a->new XElement('{DAV:}href', a)), if String.IsNullOrEmpty(Status) then nil else new Xelement('{DAV:}status', Status), 
  Propstat.Select(a->a.ToXElement), Error, if ResponseDescription = nil then nil else new XElement('{DAV:}responsedescription', ResponseDescription), 
    if Location = nil then nil else new Xelement('{DAV:}location', Location));
end;

method DavResponse.GetPropStatWithStatus(aStatus: string): DavPropStat;
begin
  result := PropStat.FirstOrDefault(a->a.Status = aStatus);
  if result = nil then begin
    result := new DavPropStat;
    result.Status := aStatus;
    result.Prop := new XElement('{DAV:}prop');
    PropStat.Add(result);
  end;
end;

method DavController.DoRequest;
begin
  consoleapp.Logger.Debug('0 Processing '+Request.Method+' for calendar '+coalesce(Calendar:Name, '{root}'));
  var lDav: array of String := nil;
  var lDepth: DavDepth := DavDepth.Infinity;
  var lHeader: string;
  if request.Headers.TryGetValue('Depth', out lHeader) then begin
    if lHeader = '0' then lDepth := DavDepth.Zero else
    if lHeader = '1' then lDepth := DavDepth.One;
  end;
  if request.Headers.TryGetValue('DAV', out lHeader) then begin
    lDav := lHeader.Split([','], StringSplitOptions.RemoveEmptyEntries).Select(a-> a.Trim()).ToArray;
  end;
  fController := new CalendarController(self.Auth.Username, Auth.Membership);
  Headers.Headers.Add('dav', '1, 2, calendar-access, calendar-schedule, calendar-auto-schedule, calendar-query-extended, calendarserver-principal-property-search');

  if Path <> nil then begin
    Calendar := fController.Calendars.FirstOrDefault(a->a.Name = Path.Value);
    if Calendar = nil then begin
      Send404;
      exit;
    end;
    Path := Path.Next;
    if Path <> nil then begin
      Document := Path.Value;
      if Path.Next <> nil then begin
        Send404;
        exit;
      end;
    end;
  end;

  consoleapp.Logger.Debug('Processing '+Request.Method+' for calendar '+coalesce(Calendar:Name, '{root}'));
  case Request.Method of
    'PROPFIND': ParsePropFind(lDepth, lDav);
    'OPTIONS': ParseOptions(lDepth, lDav);
    'PUT': ParsePut(lDepth, lDav);
    'DELETE': ParseDelete(lDepth, lDav);
    'REPORT': ParseReport(lDepth, lDav);
    'PROPPATCH': ParsePropPatch(lDepth, lDav);
    'MOVE': ParseMove(lDepth, lDav);
    'GET', 'HEAD': begin
      var lAct := Get;
      if lACt = nil then SendMethodNotSupported else lAct(self);
    end
    //'REPORT': 
  else
    SendMethodNotSupported;
  end;
end;

method DavController.ParsePropFind(adepth: DavDepth; aDav: array of string);
begin
  Body.Connect(new BufferedConsumer(method(arg: BufferedConsumer) begin
    if arg.Error <> nil then SendInternalError else begin
      try
        var lDoc := XDocument.Load(arg.Data);
         ConsoleApp.Logger.Debug('Logging propfind request: '+ldoc.ToString());
        if lDoc.Root:Name <> XName.Get('{DAV:}propfind') then raise new ArgumentException('Expected {DAV:}propfind in the root!');
        var lRoot := lDoc.Root.Elements().FirstOrDefault(a->a.Name.Namespace = 'DAV:');
        var lItem := new PropFindRequest();
        lItem.Dav := aDav;
        lItem.Depth := aDepth;
        if lRoot = nil then lItem.Mode := PropFindMode.AllProp else 
        if lRoot.Name.LocalName  = 'allprop' then  lItem.Mode := PropFindMode.AllProp else
        if lRoot.Name.LocalName  = 'propname' then  lItem.Mode := PropFindMode.PropName else 
        if lRoot.Name.LocalName = 'prop' then begin
          lItem.Properties := lRoot.Elements.ToArray;
        end else raise new ArgumentException('allprop, propname or prop expected');

        var lCB := PropFind;
        if lCB = nil then Send404 else 
          lCB(self, lItem);
      except
        on e: Exception do
        SendInternalError(e.Message);
      end;
    end;
  end));
end;

method DavController.SendPropFindResponse(aResp: DavResponses);
begin
  var lMS:= new MemoryStream;
  var lEl := aResp.ToXElement();
  //CleanXmlns(lel);
  lEl.Save(lMS, SaveOptions.OmitDuplicateNamespaces or SAveOptions.DisableFormatting);

  Headers.Status := "207 Multi-Status";
  headers.Headers.Add('Content-Type', 'text/xml; charset="utf-8"');
  var lStripHeader := (lMS.Length > 3) and (lMS.GetBuffer()[0] = $ef);
  headers.Headers.Add('Content-Length', (if lStripHeader then lMS.Length - 3 else lMS.Length).ToString);

  headers.Headers.Add('pragma', 'no-cache');
  headers.Headers.Add('cache-control', 'no-cache');

  var lBody := 
  if lStripHeader then // mono hack; skip utf8 header
  new BufferedProducer(new ARraySegment<Byte>(lMS.GetBuffer, 3, lMS.Length -3)) else
  new BufferedProducer(new ARraySegment<Byte>(lMS.GetBuffer, 0, lMS.Length));

   ConsoleApp.Logger.Debug('Logging propfind response: '+aResp.ToXElement().ToString());
  response.OnResponse(headers, lBody);

end;

method DavController.ParseOptions(adepth: DavDepth; aDav: array of string);
begin
  var lAct := self.Options;
  if lAct = nil then Send404 else begin
    lAct(self);
  end;
end;

method DavController.SendOptionsResponse(aDavAllow: array of String);
begin
  headers.Headers.Add('Content-Type', 'text/plain; charset="utf-8"');
  headers.Headers.Add('allow', String.Join(', ', aDavAllow));
  headers.Headers.Add('Content-Length','0');

  response.OnResponse(headers, nil); 
end;

method DavController.ParsePut(adepth: DavDepth; aDav: array of string);
begin
  var lAct := Put;
  if lACt = nil then Send404 else begin
    Body.Connect(new BufferedConsumer(method(arg: BufferedConsumer) begin
      if arg.Error <> nil then SendInternalError(arg.Error.ToString) else begin
        arg.Data.Position := 0;
        lACt(self, arg.Data);
      end;
    end));
  end;
end;

method DavController.SendPutResponse(aUpdated: Boolean; aTag: string);
begin
  var lSTatus: string := if aUpdated then '204 No Content' else '201 Created';
  headers.Status := lStatus;
  headers.Headers.Add('Content-Type', 'text/plain; charset="utf-8"');
  headers.Headers.Add('Content-Length','0');
  if aTag <> nil then 
    headers.Headers.Add('etag', '"'+aTag+'"');

  response.OnResponse(headers, nil);
end;

method DavController.ParseDelete(aDepth: DavDepth; aDav: array of string);
begin
  var lAct := Delete;
  if lACt = nil then Send404 else begin
    lACt(self);
  end;
end;

method DavController.SendDeleteResponse(aStatus: string);
begin
  self.Headers.Status := aStatus;
  headers.Headers.Add('Content-Type', 'text/plain; charset="utf-8"');
  headers.Headers.Add('Content-Length','0');

  response.OnResponse(headers, nil);
end;

method DavController.OnResponse(head: HttpResponseHead; body: Kayak.IDataProducer);
begin
  fIntResponse.OnResponse(head, body);
  Dispose;
end;

constructor DavController(aPath: string);
begin
  fRootPath := aPath;
end;

method DavController.Dispose;
begin
  disposeAndNil(fController);
end;

method DavController.ParseReport(adepth: DavDepth; aDav: array of string);
begin
  Body.Connect(new BufferedConsumer(method(arg: BufferedConsumer) begin
    if arg.Error <> nil then SendInternalError else begin
      try
        var lDoc := XDocument.Load(arg.Data);
        ConsoleApp.Logger.Debug('Logging REPORT request: '+ldoc.ToString());

        var lItem := new ReportRequest;
        lItem.Dav := aDav;
        lItem.Depth := adepth;
        lItem.RootRequest := lDoc.Root;
        
        var lCB := Report;
        if lCB = nil then Send404 else 
          lCB(self, lItem);
      except
        on e: Exception do
        SendInternalError(e.ToString());
      end;
    end;
  end));
end;

method DavController.ParsePropPatch(aDepth: DavDepth; aDav: array of String);
begin
    Body.Connect(new BufferedConsumer(method(arg: BufferedConsumer) begin
    if arg.Error <> nil then SendInternalError else begin
      try
        var lDoc := XDocument.Load(arg.Data);
        ConsoleApp.Logger.Debug('Logging PROPPATCH request: '+ldoc.ToString());

        var lItem := new ReportRequest;
        lItem.Dav := aDav;
        lItem.Depth := adepth;
        lItem.RootRequest := lDoc.Root;
        
        var lCB := PropPatch;
        if lCB = nil then SendForbidden else 
          lCB(self, lItem);
      except
        on e: Exception do
        SendInternalError(e.Message);
      end;
    end;
  end));

end;

method DavController.ParseMove(aDepth: DavDepth; aDav: array of string);
begin
  var lAct := Move;
  if lACt = nil then Send404 else begin
    lACt(self);
  end;
end;

method DavController.SendMoveResponse(aNew: Boolean; aLoc, eTag: string);
begin
  var lSTatus: string := if not aNew then '204 No Content' else '201 Created';
  headers.Status := lStatus;
  headers.Headers.Add('Content-Type', 'text/plain; charset="utf-8"');
  headers.Headers.Add('Content-Length','0');
  Headers.Headers.Add('Location', aLoc);
  if eTag <> nil then 
    headers.Headers.Add('etag', '"'+eTag+'"');

  response.OnResponse(headers, nil);
end;

end.
