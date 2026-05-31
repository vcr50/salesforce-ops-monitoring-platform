/**
 * Prints Experience Cloud site diagnostics for troubleshooting "Under Construction".
 * sf apex run --file scripts/apex/diagnoseExperienceSites.apex --target-org astrosoft2-dev-ed
 */
for (Network n : [
    SELECT Id, Name, Status, UrlPathPrefix
    FROM Network
    ORDER BY Name
]) {
    System.debug('NETWORK: ' + n.Name + ' | status=' + n.Status + ' | prefix=' + n.UrlPathPrefix);
}

for (Site s : [
    SELECT Id, Name, Status, UrlPathPrefix, SiteType
    FROM Site
    ORDER BY Name
]) {
    System.debug('SITE: ' + s.Name + ' | status=' + s.Status + ' | prefix=' + s.UrlPathPrefix + ' | type=' + s.SiteType);
}

for (DomainSite ds : [
    SELECT PathPrefix, SiteId, Domain.Domain
    FROM DomainSite
    ORDER BY PathPrefix
]) {
    System.debug('DOMAIN PATH: ' + ds.PathPrefix + ' -> siteId=' + ds.SiteId + ' | domain=' + ds.Domain.Domain);
}

System.debug('USE THIS URL: https://astrosoft2-dev-ed.develop.my.site.com/SentinelFlow/');
System.debug('WORKING ALT URL: https://astrosoft2-dev-ed.develop.my.site.com/Sentinelflowv2/');
System.debug('DO NOT USE: /vforcesite (inactive SEOMP Portal)');
