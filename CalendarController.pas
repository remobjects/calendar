namespace RemObjects.Calendar;

interface

uses
  RemObjects.Calendar.Calendar,
  RemObjects.DataAbstract.Linq,
  System.Collections.Generic,
  System.Linq,
  System.Text, 
  DDay.iCal;

type
  CalendarController = public class(IDisposable)
  private
    method get_Calendars: array of Calendars;
    fLDA: LinqLocalDataAdapter;
    fUsername: string;
    fGroups: array of string;
    fCalendars: array of Calendars;
  protected
  public
    constructor(aUsername: string; aGroups: array of string);
    property Calendars: array of Calendars read get_Calendars;

    method Events(aCal: Calendars): IQueryable<Events>;
    property LDA: LinqLocalDataAdapter read fLDA;
    method Dispose;
  end;

implementation

method CalendarController.get_Calendars: array of Calendars;
begin
  if fCalendars = nil then begin
    fCalendars := fLDA.GetTable<Calendars>().Where(a->(not a.Group and (a.Name = fUsername))).ToArray;
    if not fCalendars.Any(a-> not a.Group and (a.Name = fUsername)) then begin
      try
        var lCal := new Calendars();
        lCal.Description := 'auto-generated for user '+fUsername;
        lCAl.Name := fUsername;
        lCal.Color := '#ff8080';
        lCal.CTag := guid.NewGuid.ToString();
        lCal.Description :='';
        lCal.DisplayName := lCAl.Name;
        fLDA.InsertRow(lCal);
        fLDa.ApplyChanges;
      except
      end;
    end;
    fCalendars := fLDA.GetTable<Calendars>().ToArray;
  end;
  fCalendars := fCalendars.Where(a->if a.Group then ((a.LdapGroup <> nil) and fGroups.Contains(a.LdapGroup)) else a.Name = fUsername).ToArray;
  exit fCalendars;
end;

constructor CalendarController(aUsername: string; aGroups: array of String);
begin
  fGroups := aGroups;
  fUsername := aUsername;
  FLDA := new LinqLocalDataAdapter();
  FLDa.UseBindableClass := false;
  FLDA.ServiceName := 'DataService';
  
end;

method CalendarController.Events(aCal: Calendars): IQueryable<Events>;
begin
  exit fLDA.GetTable<Events>.Where(a->a.CalendarID = aCal.ID);
end;

method CalendarController.Dispose;
begin
  fLDA.Dispose;
end;

end.
