namespace RemObjects.Calendar;

interface

uses
  RemObjects.Calendar.Properties,
  RemObjects.DataAbstract.Server,
  System.Collections.Generic,
  System.Linq, 
  System.Net,
  DDay.iCal, 
  NLog;


type
  ConsoleApp = class
  public
    class var Logger: Logger  := LogManager.GetLogger('Kayak'); readonly;
    class method Main(args: array of String);
  end;


  IndexRequest = class(RequestHandler)
  private
  public
    method DoRequest; override;
  end;

implementation

method IndexRequest.DoRequest;
begin
  if Request.Header.RequestType not in ['GET', 'HEAD'] then SendMethodNotSupported else begin

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
  
    response.Header.ContentType := 'text/html';
    Response.ContentString := responseBody;

    state.SendResponse;

  end;
end;

class method ConsoleApp.Main(args: array of String);
begin
  Logger.Info('Starting server');
  RemObjects.DataAbstract.Server.Configuration.Load();
  var lCMGR := new ConnectionManager(true);
  lCMGR.EnableAdoConnectionPooling := true;
  lCMGR.PoolingBehavior := RemObjects.SDK.Pooling.PoolBehavior.IgnoreAndReturn;
  lCMGR.Load();
  lCMGR.ConnectionDefinitions[0].ConnectionString := Settings.Default.DB_ConnectionString;
  var lServer := new RemObjects.InternetPack.Http.AsyncHttpServer;
  lServer.BindV6 := false;
  lServer.BindingV4.Address := IPAddress.Any;
  lServer.Port := Settings.Default.Server_Port;
  var lServ := new RemObjects.InternetPack.LibUV.LibUVConnectionFactory();
  lServer.ConnectionFactory := lServ;
  var lRequestHandler := new MainRequestHandler();
  lServer.OnHttpRequest += @(lRequestHandler .OnRequest);
  lRequestHandler.Paths.TryAdd('', new RequestConstructor(-> new IndexRequest, Authenticator := CachingAuthenticator.Instance));
  lRequestHandler.Paths.TryAdd('dav', new RequestConstructor(-> new CalDavRequest('/dav/'), Authenticator := CachingAuthenticator.Instance));
  lServer.Active := true;
  
  while true do System.Threading.Thread.Sleep(1000);
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
