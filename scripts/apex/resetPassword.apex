String portalUsername = 'sentinelflow.portal.00ddl0000053505uaa@example.com';
String tempPassword = 'SentinelFlow#2026May!';

User portalUser = [
    SELECT Id, Username
    FROM User
    WHERE Username = :portalUsername
    LIMIT 1
];

System.setPassword(portalUser.Id, tempPassword);

System.debug('Portal login URL: https://astrosoft2-dev-ed.develop.my.site.com/SentinelFlow/login');
System.debug('Username: ' + portalUser.Username);
System.debug('Temporary password reset to: ' + tempPassword);
