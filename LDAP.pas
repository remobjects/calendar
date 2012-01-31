namespace RemObjects.Calendar;

interface

uses
  RemObjects.Calendar.Properties,
  RemObjects.DataAbstract,
  RemObjects.InternetPack.Ldap,
  System.Collections.Concurrent,
  System.Collections.Generic,
  System.Text, 
  System.Threading, 
  System.Threading.Tasks, 
  NLog.Layouts;

type
  LDAP = public static class
  private
    class var fLdap: LdapUserLookup;
    class constructor;
  protected
  public
    class method Login(aUn, aPW: String; aContinue: Action<Exception, LdapUserLookup.LookupResults>);
  end;

  CachingAuthenticator = public class(IAuthenticator)
  private
    fCache: ConcurrentDictionary<Tuple<string,String>, Tuple<DateTime, MembershipInfo>> := new ConcurrentDictionary<Tuple<string,String>, Tuple<DateTime, MembershipInfo>>; 
  public
    property CacheTimeout: TimeSpan := new TimeSpan(0,1,0);
    method Login(aUser, aPassword: String; aContinue: Action<MembershipInfo>);

    class var Instance: CachingAuthenticator := new CachingAuthenticator;
  end;

implementation

method CachingAuthenticator.Login(aUser: String; aPassword: String; aContinue: Action<MembershipInfo>);
begin
  var lTuple := Tuple.Create(aUser, aPassword);
  var lDT, lDT2: Tuple<DateTime, MembershipInfo>;
  if fCache.TryGetValue(lTuple, out lDT) then begin
    if (lDT.Item1 +CacheTimeout > DateTime.UtcNow) then begin
      aContinue(lDT.Item2);
      exit;
    end else begin
      if fCache.TryRemove(lTuple, out lDT2)  and (lDT2 <> LDT) then begin
        fCache.TryAdd(lTuple, lDT2);
        aContinue(lDt2.Item2);
        exit;
      end;
    end;
  end;
  
  LDAP.Login(aUser, aPassword, method (ex:Exception ; aLogin:LdapUserLookup .LookupResults) begin
    if ex <> nil then ConsoleApp.Logger.ErrorException('Could not login', ex);
    var lMS: MembershipInfo := nil;
    if aLogin <> nil then begin
      lMS := new MembershipInfo;
      lMS.Username := aLogin.Username;
      lMS.UId :=aLogin.DN;
      lMS.Membership := aLogin.GroupMembership.ToArray;
    end;

    if lMS  <> nil then begin
      fCache.TryAdd(lTuple, Tuple.Create(Datetime.UtcNow, lMS));
    end;
    aContinue(lMS);
  end);
end;

class method LDAP.Login(aUn: String; aPW: String; aContinue: Action<Exception,LdapUserLookup .LookupResults>);
begin
  Async begin
    try
      aContinue(nil,fLdap.Login(aUn, aPW));
    except
      on e: Exception do 
        aContinue(e, nil);
    end;
  end;
end;

class constructor LDAP;
begin
  fLdap := new LdapUserLookup;
  fLdap.LookupDN := Settings.Default.LDAP_LoginDomain;
  fLdap.Hostname := Settings.Default.LDAP_LdapServer;
  fLdap.LookupPassword := Settings.Default.LDAP_Password;
  fLdap.UseStartTLS := true;
  fLdap.SslOptions.TargetHostName := fLdap.Hostname;
  fLdap.SslOptions.ValidateRemoteCertificate += method (sender: Object; e: RemObjects.InternetPack.SslValidateCertificateArgs); 
  begin
      e.Cancel := false; //not (Settings.Default.LDAP_CertHash = e.Certificate.GetCertHashString);
  end;
  fLdap.UserSearchBase := Settings.Default.LDAP_UserSearchBase;
  fLdap.UserFilter := Settings.Default.LDAP_UserFilter;
  fLdap.GroupSearchBase := settings.Default.Ldap_GroupSearchBase;
  fLdap.GroupFilter := Settings.Default.Ldap_GroupFilter;
  fLdap.StripGroupBaseDN := true;
end;

end.
