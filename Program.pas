namespace RemObjects.Calendar;

interface

uses
  RemObjects.Calendar.Properties,
  RemObjects.DataAbstract.Server,
  System.Collections.Generic,
  System.Linq, 
  System.Net,
  DDay.iCal, 
  Kayak,
  Kayak.Http, 
  NLog;


type
  ConsoleApp = class
  public
    class var Logger: Logger  = LogManager.GetLogger('Kayak'); readonly;
    class method Main(args: array of String);
  end;

  CalendarScheduler = class(ISchedulerDelegate)
  private
  public
    method OnException(scheduler: IScheduler; e: Exception);
    method OnStop(scheduler: IScheduler);
  end;

  IndexRequest = class(RequestHandler)
  private
  public
    method DoRequest; override;
  end;

implementation

method IndexRequest.DoRequest;
begin
  if Request.Method not in ['GET', 'HEAD'] then SendMethodNotSupported else begin

    var lCal: string;
    using lCals := new CAlendarController(Auth.Username, Auth.Membership) do
    lCal := String.Join(#13#10, lCals.CAlendars.select(a->'<li><a href="dav/'+a.Name+'">'+a.Name+'</a></li>').ToArray);
    var responseBody := "<html>

   <head><title>Welcome</title></head>
  <body>
    <h1><font size='7'>RemObjects Calendar</font></h1>
    <p>Welcome to RO Calendar Server.</p>
    <p>Calendars provided by this server for your username: </p>
<ul>
"+lCal+"
</ul>

When using iCalendar, use <a href=""/dav/"">dav/</a> as an url. Thunderbird and other clients that don't properly support collections should use the links above.

  </body>
</html>";
    var headers := new HttpResponseHead(
        Status := "200 OK",
        Headers := new Dictionary<string, string>
    );
    headers.Headers.Add('Content-Type', 'text/html');
    headers.Headers.Add('Content-Length', responseBody.Length.ToSTring);
    var lBody := new BufferedProducer(responseBody);

    response.OnResponse(headers, lBody);

  end;
end;

method CalendarScheduler.OnException(scheduler: IScheduler; e: Exception);
begin
  ConsoleApp.Logger.Info('Exception in server: '+e);
end;

method CalendarScheduler.OnStop(scheduler: IScheduler);
begin
  ConsoleApp.Logger.Info('Stopped server');
end;

class method ConsoleApp.Main(args: array of String);
begin
  Logger.Info('Starting server');
  RemObjects.DataAbstract.Server.Configuration.Load();
  var lCMGR := new ConnectionManager(true);
  lCMGR.EnableAdoConnectionPooling := true;
  lCMGR.PoolingBehavior := RemObjects.SDK.Pooling.PoolBehavior.IgnoreAndReturn;
  lCMGR.Load();
  var lScheduler := KayakScheduler.Factory.Create(new CalendarScheduler());
  var lRequestHandler := new MainRequestHandler();
  lRequestHandler.Paths.TryAdd('', new RequestConstructor(-> new IndexRequest, Authenticator := CachingAuthenticator.Instance));
  lRequestHandler.Paths.TryAdd('dav', new RequestConstructor(-> new CalDavRequest('/dav/'), Authenticator := CachingAuthenticator.Instance));
  var lServer := KayakServer.Factory.CreateHttp(lRequestHandler, lScheduler);
  using lServer.Listen(new IPEndPoint(IPAddress.Any, Settings.Default.Server_Port)) do begin
    lScheduler.Start();
  end;
end;

end.
{
  VCalendar [
     0..N timezones (got two)
     0..N todos
     0..N events [
       DTStart
       DTEnd
       Location (string)
       GeographicalLocation (IGeographicalLocation)
       Status (EventStatus)
       TRansparency (Itransparency)
       Created
       LastModified
       Alarms [
       ]
       RecurrenceRoles [
       ]
     ]

  ]
}
