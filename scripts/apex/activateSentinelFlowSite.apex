/**
 * Activates and publishes the SentinelFlow Experience Cloud site.
 * Run when the site shows "Under Construction" or "DownForMaintenance".
 *
 * sf apex run --file scripts/apex/activateSentinelFlowSite.apex --target-org astrosoft2-dev-ed
 */
List<Network> networks = [
    SELECT Id, Name, Status, UrlPathPrefix
    FROM Network
    WHERE Name = 'SentinelFlow'
    LIMIT 1
];

if (networks.isEmpty()) {
    System.debug('ERROR: SentinelFlow network not found in this org.');
} else {
    Network site = networks[0];
    System.debug('Before: ' + site.Name + ' status=' + site.Status + ' prefix=' + site.UrlPathPrefix);

    if (site.Status != 'Live') {
        site.Status = 'Live';
        update site;
        System.debug('Updated status to Live.');
    } else {
        System.debug('Site is already Live.');
    }

    System.debug('Publish in Experience Builder or run: sf community publish --name SentinelFlow --target-org <alias>');
    System.debug('Site URL: https://' + URL.getOrgDomainUrl().getHost().replace('.my.salesforce.com', '.my.site.com') + '/SentinelFlow/');
}
