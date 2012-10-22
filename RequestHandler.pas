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
  RemObjects.InternetPack.Http;

type
  MainRequestHandler = public class
  private
    fPaths: ConcurrentDictionary<string, RequestConstructor> := new ConcurrentDictionary<string, RequestConstructor>;
  protected
    method Send404(aPath: LinkedListNode<string>; state: AsyncHttpContext);
  public
    method OnRequest(sender: Object; e: OnAsyncHttpRequestArgs);

    property Paths: ConcurrentDictionary<string, RequestConstructor> read fPaths;
  end;

  RequestConstructor = public class
  private
    fInstantiator: Func<RequestConstructor,RequestHandler>;
    method SendAuthFailed(state: AsyncHttpContext);
  public
    constructor(aInstantiator: Func<RequestConstructor,RequestHandler>);
    method Request(aPath: LinkedListNode<string>; state: AsyncHttpContext);

    property Authenticator: IAuthenticator;
    property Instantiator: Func<RequestConstructor,RequestHandler> read fInstantiator;

    method ProcessRequest(aMembershipInfo: MembershipInfo;aPath: LinkedListNode<string>;  state: AsyncHttpContext); virtual;
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
  public
    property Path: LinkedListNode<string>;
    property Auth: MembershipInfo;
    property State: AsyncHttpContext;
    property Request: AsyncHttpRequest read State.CurrentRequest;
    property Response: HttpServerResponse read State.CurrentResponse;
    
    method DoRequest; abstract;
    method Done; virtual; 

    method SendForbidden;
    method Send404;
    method SendMethodNotSupported;
    method SendRedir(aPath: string);
    method SendInternalError(aError: string := nil);
    method SendXmlResponse(aStatus: string; aDoc: XDocument);
  end;


  
implementation

method RequestHandler.Send404;
begin
  var responseBody := "The resource you requested ('" + request.Header.RequestPath + "') could not be found.";
  response.Code := 404;
  response.ResponseText := 'Not Found';
  response.ContentString := responseBody;
  response.Header.ContentType := 'text/plain';
  Done;
  ConsoleApp.Logger.Debug('404: '+responseBody);
end;

method RequestHandler.SendMethodNotSupported;
begin
  var responseBody := "The method "+request.Header.RequestType+" is not allowed";
  response.Code := 405;
  response.ResponseText := 'Method Not Allowed';
  response.ContentString := responseBody;
  response.Header.ContentType := 'text/plain';
  Done;

end;

method RequestHandler.SendForbidden;
begin
  var responseBody := "The target url "+request.header.RequestPath+' is forbidden';
  response.Code := 403;
  response.ResponseText := 'Forbidden';
  response.ContentString := responseBody;
  response.Header.ContentType := 'text/plain';
  Done;
end;

method RequestHandler.SendRedir(aPath: string);
begin
  var responseBody := "<html><head><title>Moved!</title></head><body><h1>Moved</h1>This resource was moved to <a href="""+ aPath + """>"+aPath+"</a></body></html>";
  response.Code := 303;
  response.ResponseText := 'Move Temporarily';
  response.ContentString := responseBody;
  response.Header.ContentType := 'text/html';
  Done;
end;

method RequestHandler.SendInternalError(aError: string);
begin
  var responseBody := if not STring.IsNullOrEmpty(aError) then aError else "The server encountered an unexpected condition which prevented it from fulfilling the request.";
  response.Code := 500;
  response.ResponseText := 'Internal Server Error';
  response.ContentString := responseBody;
  response.Header.ContentType := 'text/plain';
  Done;
end;

method RequestHandler.SendXmlResponse(aStatus: string; aDoc: XDocument);
begin
  var lMS:= new MemoryStream;
  //DavController.CleanXmlns(aDoc.Root);
  aDoc.Save(lMS, SaveOptions.OmitDuplicateNamespaces or SAveOptions.DisableFormatting);

  Response.Header.SetHeaderValue('pragma', 'no-cache');
  Response.Header.SetHeaderValue('cache-control', 'no-cache');
  var lStripHeader := (lMS.Length > 3) and (lMS.GetBuffer()[0] = $ef);
    var lBody := 
    if lStripHeader then // mono hack; skip utf8 header
    new ARraySegment<Byte>(lMS.GetBuffer, 3, lMS.Length -3) else
    new ARraySegment<Byte>(lMS.GetBuffer, 0, lMS.Length);

    ConsolEapp.Logger.Debug('Logging XML response '+aStatus+#13#10+aDoc.ToString);
  
  response.Code := Int32.Parse(aStatus.Substring(0, aStatus.IndexOf(' ')));
  response.ResponseText := aStatus.Substring(aStatus.IndexOf(' ')+1);
  response.ContentStream := new MemoryStream(lBody.Array, lBody.Offset, lBody.Count, false);
  response.Header.ContentType := 'text/xml; charset="utf-8"';
  Done;
end;

method RequestHandler.Done;
begin
  STate.SendResponse;
end;

constructor RequestConstructor(aInstantiator: Func<RequestConstructor,RequestHandler>);
begin
  if aInstantiator = nil then raise new ArgumentNullException('aInstantiator');
  fInstantiator := aInstantiator;
end;

method RequestConstructor.Request(aPath: LinkedListNode<string>; state: AsyncHttpContext);
begin
  if Authenticator = nil then begin
    ProcessRequest(nil, aPath, state);
  end else begin
    var lAuth: string := coalesce(state.CurrentRequest.Header.GetHeaderValue('Authorization'), '');
    if  not lAuth.StartsWith('Basic ', StringComparison.InvariantCultureIgnoreCase) then begin SendAuthFailed(state); exit end;
    lAuth := lAuth.Substring(6);
    try
      lAuth := Encoding.Utf8.GetString(Convert.FromBase64String(lAuth));
    except
      SendAuthFailed(state); 
      exit;
    end;

    var lAuthInfo := lAuth.Split([':'], 2);
    if lAuthInfo.Length < 2 then begin
      SendAuthFailed(state);
      exit;
    end;

    Authenticator.Login(lAuthInfo[0], lAuthInfo[1], method (act: MembershipInfo) begin
      if act = nil then begin
        SendAuthFailed(state);
        exit;
      end;

      ProcessRequest(act, aPath, state);
    end);
  end;
end;

method RequestConstructor.SendAuthFailed(state: AsyncHttpContext);
begin
  var responseBody := "Authentication required";
  state.CurrentResponse.Code := 401;
  state.CurrentResponse.ResponseText := 'Unauthorized';
  state.CurrentResponse.Header.SetHeaderValue('WWW-Authenticate', 'Basic realm="Calendar Server"');
  state.CurrentResponse.Header.SetHeaderValue('Content-Type', 'text/plain');
  state.CurrentResponse.Header.SetHeaderValue('Content-Length', responseBody.Length.ToSTring);
  state.CurrentResponse.ContentBytes := [];
  
  state.SendResponse;
end;

method RequestConstructor.ProcessRequest(aMembershipInfo: MembershipInfo; aPath: LinkedListNode<string>; state: AsyncHttpContext);
begin
  var lHandler := Instantiator(self);
  lHandler.Auth := aMembershipInfo;
  lHandler.Path := aPath;
  lHandler.State := state;

  lHandler.DoRequest;
end;



method MainRequestHandler.OnRequest(sender: Object; e: OnAsyncHttpRequestArgs);
begin
  var state := e.Context;
  ConsoleApp.Logger.Debug('Request: '+state.CurrentRequest.Header.RequestType+' '+ state.CurrentRequest.Header.RequestPath);
  var lPath :=  state.CurrentRequest.Header.RequestPath;
  if lPath.StartsWith('/') then lPath := lPath.SubString(1);
  var lList := new LinkedList<string>(lPath.Split(['/'], StringSplitOptions.RemoveEmptyEntries));
  var lName := coalesce(lList.FirstOrDefault(), '');
  var lP: RequestConstructor;
  if not fPaths.TryGetValue(lName, out lP) or (lP = nil) then 
    Send404(lList.First, state)
  else
    lP.Request(lList.First:Next,state);
end;

method MainRequestHandler.Send404(aPath: LinkedListNode<string>; state: AsyncHttpContext);
begin
  var responseBody := "The resource you requested ('" + state.CurrentRequest.Header.RequestPath + "') could not be found.";
  state.CurrentResponse.Code := 404;
  State.CurrentResponse.ResponseText := 'Not Found';
  state.CurrentResponse.Header.ContentType := 'text/plain';
  state.CurrentResponse.ContentString := responseBody;
  state.SendResponse;

end;

end.
