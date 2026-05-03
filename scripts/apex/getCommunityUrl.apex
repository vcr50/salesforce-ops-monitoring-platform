for(Network n : [SELECT Name, UrlPathPrefix FROM Network]) {
    String url = Network.getLoginUrl(n.Id);
    System.debug('PORTAL_URL: ' + n.Name + ' -> ' + url);
}
