namespace RemObjects.Calendar;

interface

uses
  System.Collections.Concurrent,
  System.Collections.Generic,
  System.Diagnostics,
  System.IO,
  System.Linq,
  System.Net.Cache,
  System.Net.Security,
  System.Text, 
  System.Threading,
  System.Xml.Linq,
  Kayak, 
  Kayak.Http;

type
  MainRequestHandler = public class(IHttpRequestDelegate)
  private
    fPaths: ConcurrentDictionary<string, RequestConstructor> := new ConcurrentDictionary<string, RequestConstructor>;
  protected
    method Send404(aPath: LinkedListNode<string>; head: HttpRequestHead; body: IDataProducer; response: IHttpResponseDelegate);
  public
    method OnRequest(head: HttpRequestHead; body: IDataProducer; response: IHttpResponseDelegate);

    property Paths: ConcurrentDictionary<string, RequestConstructor> read fPaths;
  end;

  RequestConstructor = public class
  private
    fInstantiator: Func<RequestConstructor,RequestHandler>;
    method SendAuthFailed(head: HttpRequestHead; body: IDataProducer; response: IHttpResponseDelegate);
  public
    constructor(aInstantiator: Func<RequestConstructor,RequestHandler>);
    method Request(aPath: LinkedListNode<string>; head: HttpRequestHead; body: IDataProducer; response: IHttpResponseDelegate); 

    property Authenticator: IAuthenticator;
    property Instantiator: Func<RequestConstructor,RequestHandler> read fInstantiator;

    method ProcessRequest(aMembershipInfo: MembershipInfo;aPath: LinkedListNode<string>;  head: HttpRequestHead; body: IDataProducer; response: IHttpResponseDelegate); virtual;
  end;

  IAuthenticator = public interface
    method Login(aUser, aPassword: string; aContinue: Action<MembershipInfo>);
  end;

  MembershipInfo = public class
  private
  public
    property Username: string;
    property UID: string;
    property Membership: array of String;
  end;

  RequestHandler = public abstract class
  private
    fResponse : IHttpResponseDelegate;
  public
    property Path: LinkedListNode<string>;
    property Auth: MembershipInfo;
    property Request: HttpRequestHead;
    property Body: IDataProducer;
    property Response: IHttpResponseDelegate read fResponse write fResponse; virtual;
    var Headers: HttpResponseHead := new HttpResponseHead(Status := "200 OK", Headers := new Dictionary<string, string>);

    method DoRequest; abstract;

    method SendForbidden;
    method Send404;
    method SendMethodNotSupported;
    method SendRedir(aPath: string);
    method SendInternalError(aError: string := nil);
    method SendXmlResponse(aStatus: string; aDoc: XDocument);
  end;


  BufferedProducer = public class(IDataProducer)
  private
    var     data: ArraySegment<System.Byte>;

  public
    constructor (adata: System.String);
    constructor (adata: System.String; encoding: Encoding);
    constructor (adata: array of System.Byte);
    constructor (adata: ArraySegment<System.Byte>);

    method Connect(channel: IDataConsumer): IDisposable;
  end;

  BufferedConsumer = public class(IDataConsumer)
  private
    fMaxSize: Integer;
    fError: Exception;
    fData: MemoryStream := new MemoryStream;
    fCallback: Action<BufferedConsumer>;
    method OnData(adata: ArraySegment<Byte>; continuation: Action): Boolean;
    method OnEnd;
    method OnError(e: Exception);
  public
    constructor(aCallback: Action<BufferedConsumer>; aMax: Integer := 1 * 1024 * 1024);
    
    class var Overflow: OverflowException := new OverflowException; readonly;
    property Error: Exception read fError;
    property Data: MemoryStream read fData;

  end;

implementation

constructor BufferedConsumer(aCallback: Action<BufferedConsumer>;aMax: Integer := 1 * 1024 * 1024);
begin
  if aCallback = nil then raise new ArgumentNullException('aCallback');
  fMaxSize := aMax;
  fCallback := aCallback;
end;

method BufferedConsumer.OnData(adata: ArraySegment<Byte>; continuation: Action): Boolean;
begin
  if fData.Length + adata.Count > fMaxSize then begin
    fError := Overflow;
    exit true; // don't read more. this expects the continuation thing to be called; which we don't but we just send a failure
  end;

  fData.Write(aData.Array, aData.Offset, aData.Count);

  exit false; // call again automatically
end;

method BufferedConsumer.OnEnd;
begin
  Data.Position :=0;
  fCallback(Self);
end;

method BufferedConsumer.OnError(e: Exception);
begin
  fError := e;
  fCallback(Self);
end;

method RequestHandler.Send404;
begin
  var responseBody := "The resource you requested ('" + request.Uri + "') could not be found.";
  headers.Status := "404 Not Found";
  headers.Headers['Content-Type'] := 'text/plain';
  headers.Headers['Content-Length'] := responseBody.Length.ToSTring;
  var lBody := new BufferedProducer(responseBody);

  response.OnResponse(headers, lBody);
  ConsoleApp.Logger.Debug('404: '+responseBody);
end;

method RequestHandler.SendMethodNotSupported;
begin
  var responseBody := "The method "+request.Method+" is not allowed";
  headers.Status := "405 Method Not Allowed";
  headers.Headers.Add('Content-Type', 'text/plain');
  headers.Headers.Add('Content-Length', responseBody.Length.ToSTring);
  var lBody := new BufferedProducer(responseBody);

  response.OnResponse(headers, lBody);
end;

method RequestHandler.SendForbidden;
begin
  var responseBody := "The target url "+request.uri+' is forbidden';
  headers.Status := "403 Forbidden";
  headers.Headers.Add('Content-Type', 'text/plain');
  headers.Headers.Add('Content-Length', responseBody.Length.ToSTring);
  var lBody := new BufferedProducer(responseBody);

  response.OnResponse(headers, lBody);
end;

method RequestHandler.SendRedir(aPath: string);
begin
  var responseBody := "<html><head><title>Moved!</title></head><body><h1>Moved</h1>This resource was moved to <a href="""+ aPath + """>"+aPath+"</a></body></html>";
  headers.Status := "303 Moved Temporarily";
  headers.Headers.Add('Location', aPath);
  headers.Headers['Content-Type'] :='text/html';
  headers.Headers['Content-Length'] := responseBody.Length.ToSTring;
  var lBody := new BufferedProducer(responseBody);

  response.OnResponse(headers, lBody);
end;

method RequestHandler.SendInternalError(aError: string);
begin
  var responseBody := if not STring.IsNullOrEmpty(aError) then aError else "The server encountered an unexpected condition which prevented it from fulfilling the request.";
  headers.Status := "500 Internal Server Error";
  headers.Headers['Content-Type'] := 'text/plain';
  headers.Headers['Content-Length'] := responseBody.Length.ToSTring;
  var lBody := new BufferedProducer(responseBody);

  response.OnResponse(headers, lBody);
  ConsoleApp.Logger.Error('Internal error'+aError+' '+new StackTrace().ToString());
end;

method RequestHandler.SendXmlResponse(aStatus: string; aDoc: XDocument);
begin
  var lMS:= new MemoryStream;
  //DavController.CleanXmlns(aDoc.Root);
  aDoc.Save(lMS, SaveOptions.OmitDuplicateNamespaces or SAveOptions.DisableFormatting);

  headers.Status := aStatus;
  headers.Headers.Add('Content-Type', 'text/xml; charset="utf-8"');
  var lStripHeader := (lMS.Length > 3) and (lMS.GetBuffer()[0] = $ef);
  headers.Headers.Add('Content-Length', (if lStripHeader then lMS.Length - 3 else lMS.Length).ToString);

  headers.Headers.Add('pragma', 'no-cache');
  headers.Headers.Add('cache-control', 'no-cache');
  
    var lBody := 
    if lStripHeader then // mono hack; skip utf8 header
    new BufferedProducer(new ARraySegment<Byte>(lMS.GetBuffer, 3, lMS.Length -3)) else
    new BufferedProducer(new ARraySegment<Byte>(lMS.GetBuffer, 0, lMS.Length));

    ConsolEapp.Logger.Debug('Logging XML response '+aStatus+#13#10+aDoc.ToString);
  Self.get_Response().OnResponse(headers, lBody);
end;

constructor RequestConstructor(aInstantiator: Func<RequestConstructor,RequestHandler>);
begin
  if aInstantiator = nil then raise new ArgumentNullException('aInstantiator');
  fInstantiator := aInstantiator;
end;

method RequestConstructor.Request(aPath: LinkedListNode<string>; head: HttpRequestHead; body: IDataProducer; response: IHttpResponseDelegate);
begin
  if Authenticator = nil then begin
    ProcessRequest(nil, aPath, head, body, response);
  end else begin
    var lAuth: string;
    if not head.Headers.TryGetValue('Authorization', out lAuth) or not lAuth.StartsWith('Basic ', StringComparison.InvariantCultureIgnoreCase) then begin SendAuthFailed(head, body, response); exit end;
    lAuth := lAuth.Substring(6);
    try
      lAuth := Encoding.Utf8.GetString(Convert.FromBase64String(lAuth));
    except
      SendAuthFailed(head, body, response); 
      exit;
    end;

    var lAuthInfo := lAuth.Split([':'], 2);
    if lAuthInfo.Length < 2 then begin
      SendAuthFailed(head, body, response); 
      exit;
    end;

    Authenticator.Login(lAuthInfo[0], lAuthInfo[1], method (act: MembershipInfo) begin
      if act = nil then begin
        SendAuthFailed(head, body, response); 
        exit;
      end;

      ProcessRequest(act, aPath, head, body, response);
    end);
  end;
end;

method RequestConstructor.SendAuthFailed(head: HttpRequestHead; body: IDataProducer; response: IHttpResponseDelegate);
begin
  var responseBody := "Authentication required";
  var headers := new HttpResponseHead(
      Status := "401 Unauthorized",
      Headers := new Dictionary<string, string>
  );
  headers.Headers.Add('WWW-Authenticate', 'Basic realm="Calendar Server"');
  headers.Headers.Add('Content-Type', 'text/plain');
  headers.Headers.Add('Content-Length', responseBody.Length.ToSTring);
  var lBody := new BufferedProducer(responseBody);

  response.OnResponse(headers, lBody);
end;

method RequestConstructor.ProcessRequest(aMembershipInfo: MembershipInfo; aPath: LinkedListNode<string>; head: HttpRequestHead; body: IDataProducer; response: IHttpResponseDelegate);
begin
  var lHandler := Instantiator(self);
  lHandler.Auth := aMembershipInfo;
  lHandler.Path := aPath;
  lHandler.Body := Body;
  lHandler.Request := head;
  lHandler.Response := response;

  lHandler.DoRequest;
end;


constructor BufferedProducer(adata: System.String);
begin
  constructor(adata, Encoding.UTF8);

end;

constructor BufferedProducer(adata: System.String; encoding: Encoding);
begin
  constructor(encoding.GetBytes(adata));

end;

constructor BufferedProducer(adata: array of System.Byte);
begin
  constructor(new ArraySegment<System.Byte>(adata));

end;

constructor BufferedProducer(adata: ArraySegment<System.Byte>);
begin
  self.data := adata

end;

method BufferedProducer.Connect(channel: IDataConsumer): IDisposable;
begin
// null continuation, consumer must swallow the data immediately.
  channel.OnData(data, nil);
  channel.OnEnd();
  exit nil
end;


method MainRequestHandler.OnRequest(head: HttpRequestHead; body: IDataProducer; response: IHttpResponseDelegate);
begin
  ConsoleApp.Logger.Debug('Request: '+head.Method+' '+ head.Uri);
  var lPath :=  head.Path;
  if lPath.StartsWith('/') then lPath := lPath.SubString(1);
  var lList := new LinkedList<string>(lPath.Split(['/'], StringSplitOptions.RemoveEmptyEntries));
  var lName := coalesce(lList.FirstOrDefault(), '');
  var lP: RequestConstructor;
  if not fPaths.TryGetValue(lName, out lP) or (lP = nil) then 
    Send404(lList.First, head, body, response)
  else
    lP.Request(lList.First:Next, head, body, response);
end;

method MainRequestHandler.Send404(aPath: LinkedListNode<string>; head: HttpRequestHead; body: IDataProducer; response: IHttpResponseDelegate);
begin
  var responseBody := "The resource you requested ('" + head.Uri + "') could not be found.";
  var headers := new HttpResponseHead(
      Status := "404 Not Found",
      Headers := new Dictionary<string, string>
  );
  headers.Headers.Add('Content-Type', 'text/plain');
  headers.Headers.Add('Content-Length', responseBody.Length.ToSTring);
  var lBody := new BufferedProducer(responseBody);

  response.OnResponse(headers, lBody);

end;

end.
