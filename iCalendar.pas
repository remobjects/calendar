namespace RemObjects.Calendar;

interface

uses
  RemObjects.Calendar.Calendar,
  RemObjects.DataAbstract.Linq,
  System.Collections,
  System.Collections.Generic,
  System.IO,
  System.Linq,
  System.Text, 
  DDay.iCal, 
  DDay.iCal.Serialization.iCalendar;

type
  iCalendarUtils = public static class
  private
  protected
  public
    class method ICalendarToString(aCalendar: Events; rda: LinqDataAdapter): string;
    class method ICalenderToEvent(aCalendar: Events; rda: LinqDataAdapter; aTimezones: iCalendar): &Event;
    class method StreamToEvent(aStream: Stream; out aAlarms: array of Alarms; out aRecurs: array of Recurrences): &Events;
    class method EventToEvents(aData: IEvent; out aAlarms: array of Alarms; out aRecurs: array of Recurrences): &Events;
    class method StreamToCalendar(aStream: Stream): iCalendar;
    class method ICalendarToString(aCalendar: &Event; rda: LinqDataAdapter): string;
  end;

implementation

method iCalendarUtils.ICalendarToString(aCalendar: Events; rda: LinqDataAdapter): string;
begin
  var r := new iCalendar;
  r.ProductID := '-//remobjects.com//NONSGML Calendar v1.0//EN';

  r.Events.Add(ICalenderToEvent(aCalendar, rda, r));
  var lSer := new iCalendarSerializer;
  exit lSer.SerializeToString(r);
end;

method iCalendarUtils.ICalendarToString(aCalendar: &Event; rda: LinqDataAdapter): string;
begin
  var r := new iCalendar;
  r.ProductID := '-//remobjects.com//NONSGML Calendar v1.0//EN';

  r.Events.Add(aCalendar);
  var lSer := new iCalendarSerializer;
  exit lSer.SerializeToString(r);
end;


class method iCalendarUtils.ICalenderToEvent(aCalendar: Events; rda: LinqDataAdapter; aTimezones: iCalendar): &Event;
begin
  result := new &Event;
  result.Start := new iCalDateTime(aCalendar.DTStart, IsUniversalTime := true);
  result.End := new iCalDateTime(aCalendar.DTEnd, IsUniversalTime := true);
  result.Location := aCalendar.Location;
  if assigned(aCalendar.GEOLat) and assigned(aCalendar.GEOLon) then 
  result.GeographicLocation := new GeographicLocation(double(aCalendar.GEOLat), double(aCalendar.GEOLon));
  result.Status := EventStatus(aCalendar.Status);
  result.Created := new iCalDateTime(aCalendar.Created, IsUniversalTime := true);
  result.LastModified := new iCalDateTime(aCalendar.LastUpdated, IsUniversalTime := true);
  if result.Resources  = nil then result.Resources  := new List<String>;
  for each el in aCAlendar.Resources:Split([#13#10, #13, #10], StringsplitOptions.RemoveEmptyEntries) do
    result.Resources .add(el);
  if result.Categories = nil then result.Categories := new List<string>;
  for each el in aCAlendar.Categories:Split([#13#10, #13, #10], StringsplitOptions.RemoveEmptyEntries) do
    result.Categories.add(el);
  result.Description := aCalendar.Description;
  result.Priority := aCalendar.Priority;
  result.Summary := aCalendar.Summary;
  result.UID := aCalendar.Uid;
  result.RecurrenceID := if  aCalendar.RecurID = nil then nil else new iCalDateTime(DateTime(aCalendar.RecurID));
  var lItems := rda.Execute([rda.GetTable<Alarms>().Where(a->a.EventID = aCalendar.ID), rda.GetTable<Recurrences>().Where(a->a.EventID = aCalendar.ID)]);

  for each el in IEnumerable<Alarms>(lItems[0]) do  begin
    var lAlarm := new Alarm();
    lAlarm.Summary := el.Summary;
    lAlarm.Description := el.Description;
    lAlarm.Repeat := el.Repeat;
    if assigned(el.RelativeTime) then 
      lAlarm.Trigger := new Trigger(Timespan.FromSeconds(Integer(el.RelativeTime)))
    else
      lAlarm.Trigger := new Trigger(DateTime := new iCalDateTime(DateTime(el.Time)));
    lAlarm.Trigger .Related := TriggerRelation(el.TriggerRelation);
    result.Alarms.Add(lAlarm);
  end;
  for each el in IEnumerable<Recurrences>(lItems[1]) do begin
    result.RecurrenceRules.add(new RecurrencePattern(el.Value));
  end;
  result.IsAllDay := aCalendar.AllDay;
  if result.IsAllDay then begin
    result.Start.HasTime := false;
    result.End.HasTime := false;
  end else if not string.IsNullOrEmpty(aCalendar.TimezoneInfo) then begin
     var lItem := iCalTimeZone(iCalTimeZone.LoadFromStream(new StringReader(aCalendar.TimeZoneInfo)));
     if assigned(lItem) then begin
       if not atimezones.TimeZones.Any(a->a.Name = lItem.Name) then
         aTimezones.AddTimeZone(lItem);
        var lFI := lItem.TimeZoneInfos.FirstOrDefault(a->a.TimeZoneName = aCalendar.TimeZone);
        if assigned(lfI) then begin
          result.Start := result.Start.ToTimeZone(lFI);
          result.Start := new iCalDateTime(result.Start.Year, result.start.Month, result.Start.Day, result.Start.Hour, result.Start.Minute, result.Start.Second, lItem.TZID, aTimezones);
          result.ENd := result.End.ToTimeZone(lFI);
          result.End := new iCalDateTime(result.end.Year, result.end.Month, result.end.Day, result.end.Hour, result.end.Minute, result.end.Second, lItem.TZID, aTimezones);
        end;
     end;
  end;
end;

class method iCalendarUtils.StreamToEvent(aStream: Stream; out aAlarms: array of Alarms; out aRecurs: array of Recurrences): &Events;
begin
  var lData := StreamToCalendar(aStream);
  if lData.Events.Count <> 1 then raise new ArgumentException();
  exit eventtoEvents(lData.Events[0], out aAlarms, out aRecurs);
end;

class method iCalendarUtils.StreamToCalendar(aStream: Stream): iCalendar;
begin
  var lData := iCalendar.LoadFromStream(aStream);
  if lData.Count <> 1 then raise new ArgumentException;
  exit lData[0] as iCalendar;
end;

class method iCalendarUtils.EventToEvents(aData: IEvent; out aAlarms: array of Alarms; out aRecurs: array of Recurrences): Events;
begin
  result := new Events;
  Result.DTStart := aData.Start.UTC;
  result.DTEnd := aData.End.UTC;
  result.Location := aData.Location;
  result.AllDay := aData.IsAllDay;
  if result.AllDay then begin
    Result.DTStart := new DateTime(aData.Start.Year, aData.Start.Month, aData.Start.Day, 0,0,0,DateTimeKind.Utc);
    Result.DTEnd := new DateTime(aData.End.Year, aData.End.Month, aData.End.Day, 0,0,0,DateTimeKind.Utc);
  end else begin
    if (aData.Start.TimeZoneName <> nil) and (aData.Start.TimeZoneName = aData.End.TimeZoneName) then begin
      var lSer := new iCalendarSerializer;
      result.TimeZoneInfo := String.Join('',aData .Calendar.TimeZones.Select(a-> lSer.SerializeToString(a)).ToArray);
      result.TimeZone := aData.Start.TimeZoneName;
    end;
  end;

  if aData.GeographicLocation <> nil then begin
    result.GEOLat := aData.GeographicLocation.Latitude;
    result.GEOLon := aData.GeographicLocation.Longitude;
  end;
  result.Status := Integer(aData.Status);
  if aData .Resources.Count > 0 then
  result.Resources := coalesce(String.Join(#13#10,aData .Resources.ToArray), '');
  if aData .Categories.Count > 0 then
  result.Categories := coalesce(STring.Join(#13#10, adata.Categories.ToArray), '');
  result.Description := aData.Description;
  result.Priority := aData.Priority;
  result.Summary := aData.Summary;
  result.Uid := aData.UID
  ;
  result.RecurID := if aData.RecurrenceID = nil then nil else aData.RecurrenceID.UTC;

  if aData.Alarms.Count= 0 then 
    aAlarms := nil
  else begin
    aAlarms := new Alarms[aData.Alarms.Count];
    for each el in aData.Alarms index n do begin
      aAlarms[n] := new Alarms(Summary := el.Summary, Description := el.Description, &Repeat := el.Repeat, TriggerRelation := Integer(el.Trigger.Related));
      if el.Trigger.IsRelative then begin
        aAlarms[n].RelativeTime := Integer(if el.Trigger.Duration = nil then 0.0 else  el.Trigger.Duration.TotalSeconds);
      end else
        aAlarms[n].Time := el.Trigger.DateTime.UTC;
    end;
  end;
  if aData.RecurrenceRules.Count= 0 then 
    aRecurs := nil
  else begin
    aRecurs := new Recurrences[aData.RecurrenceRules.Count];
    for each el in aData.RecurrenceRules index n do
      aRecurs[n] := new Recurrences(Value := el.ToString);
  end;
end;


end.
