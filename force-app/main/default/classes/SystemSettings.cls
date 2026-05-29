/**
 * SystemSettings
 * Utility class to fetch global thresholds and configurations.
 *
 * @author Tomcodex
 * @version 1.0
 */
@SuppressWarnings('PMD.ApexDoc')
public with sharing class SystemSettings {

    private static Map<String, Decimal> settingsCache = new Map<String, Decimal>();
    private static Map<String, Decimal> overrides = new Map<String, Decimal>();

    public static void setOverride(String name, Decimal value) {
        overrides.put(name, value);
    }

    public static void clearOverrides() {
        overrides.clear();
    }

    public static Decimal get(String settingName, Decimal defaultValue) {
        if (overrides.containsKey(settingName)) {
            return overrides.get(settingName);
        }
        if (settingsCache.containsKey(settingName)) {
            return settingsCache.get(settingName);
        }

        List<System_Setting__mdt> settings = [
            SELECT Value__c 
            FROM System_Setting__mdt 
            WHERE DeveloperName = :settingName
            WITH USER_MODE
            LIMIT 1
        ];

        if (!settings.isEmpty() && settings[0].Value__c != null) {
            settingsCache.put(settingName, settings[0].Value__c);
            return settings[0].Value__c;
        }

        return defaultValue;
    }

    public static Integer getInt(String settingName, Integer defaultValue) {
        return Integer.valueOf(get(settingName, defaultValue));
    }
}