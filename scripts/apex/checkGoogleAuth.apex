for (AuthProvider ap : [SELECT DeveloperName, ConsumerKey, ConsumerSecret FROM AuthProvider WHERE DeveloperName = 'Google']) {
    System.debug('GOOGLE_AUTH_KEY: ' + ap.ConsumerKey);
    System.debug('GOOGLE_AUTH_SECRET: ' + ap.ConsumerSecret);
}
