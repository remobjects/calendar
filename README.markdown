What is it?

It's a CALDAV calendar server for companies that use LDAP. Each user gets his own calendar, and depending 
on the LDAP group the user is a member of, gets access to the group calendars associated with that calendar.
The server works on mono and .NET.

Written using Oxygene for .NET

# Getting started

* Get and install RemObjects Data Abstract.
* Get and install PostGreSQL and create a new user & db owned by that user, and import the SQL script given here.
** The code isn't tied to PGSQL at all, but we only include a SQL script for this database at the moment, Data Abstract can work with most databases that have a .NET library.
* Edit app.config and adjust the properties to their right values
** LDAP_LoginDomain: username (full DN) for an ldap user that can find & bind users.
** LDAP_Password: password for this user.
** LDAP_LdapServer: ldap server address
** LDAP_CertHash: hash for the SSL certificate used by LDAP; should match the hash in the SSL certificate only if UseSSL is true.
** LDAP_UserSearchBase: search base for the users in ldap, for example: ou=users,dc=yourcompany,dc=com
** LDAP_GroupSearchBase: search base for the groups in ldap, for example ou=groups,dc=yourcompany,dc=com
** LDAP_UserFilter: filter for the users; (objectClass=inetOrgPerson) usually is a good bet
** LDAP_GroupFilter: filter for the groups; for example: (objectClass=groupOfNames)
** LDAP_UseSSL: set to true if you want to use SSL
** Server_Port: port for the server.
* Then open the RemObjects.Calendar.daConnections and change the connection string to match the details for your PostGreSQL config.
* Optionally, open the NLog.config file to adjust the logging configuration. 
* Build and Run

# Using 

http://127.0.0.1:2222/ (if you use port 2222) will let you test the server. it will show a HTTP login dialog. Use a username and 
password that's in LDAP. Just the username (uid in ldap) should be used for this. Once that works you'll get a list of all
calendars you have access to. You always have access to an auto-generated personal calendar named as your username, nobody
else will be able to access this. Adding group calendars currently goes via SQL directly to the database. PGAdmin is a good
tool to edit the calendars table to add group tables. Todo so, add a new row that has "Group" set to true, the name should 
unique (not match a username or other group calendar). The DisplayName is what shown in some clients. The color is an html-style
color tag, like #ff8080. The LdapGroup field defines who gets access to this. It should match the name (cn) of a group under 
the GroupSearchBase given in Ldap_GroupSearchBase. For example the group: cn=test,ou=groups,dc=yourcompany,dc=com should have
LdapGroup "test". Groups that are nested in a sub element in ldap will have name.name, for example 
cn=test,ou=employees,ou=groups,dc=yourcompany,dc=com  will be employees.test in LdapGroup.
Groups will show right away to all users that have access to that group.

Apple iCal on the iPod, iPad, iPhone and Mac OS X require just the simple http://yourhost:port/dav/ as an url and will detect adds all the 
all calendars for you. Thunderbird does not detect a root folder and needs a seperate "CALDAV" calendar for each calendar to 
http://yourhost:port/dav/calendarname/