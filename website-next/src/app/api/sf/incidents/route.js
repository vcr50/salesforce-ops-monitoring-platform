import { NextResponse } from 'next/server';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export async function GET() {
  try {
    // 1. Get Salesforce Session info using the SF CLI
    // This allows local Next.js dev to connect without needing OAuth connected apps
    const { stdout } = await execAsync('sf org display --json');
    const orgInfo = JSON.parse(stdout);
    
    if (!orgInfo.result || !orgInfo.result.accessToken) {
      throw new Error('Failed to get Salesforce access token from CLI');
    }

    const { instanceUrl, accessToken } = orgInfo.result;

    // 2. Query SentinelFlow Incidents via real Salesforce REST API
    const soql = `
      SELECT Id, Name, Status__c, Severity__c, Revenue_at_Risk__c, 
             Description__c, Auto_Heal_Status__c, CreatedDate
      FROM Incident__c 
      ORDER BY CreatedDate DESC 
      LIMIT 10
    `;
    
    const queryUrl = `${instanceUrl}/services/data/v60.0/query/?q=${encodeURIComponent(soql.trim())}`;
    
    const sfResponse = await fetch(queryUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      }
    });

    if (!sfResponse.ok) {
      const errorText = await sfResponse.text();
      throw new Error(`Salesforce API Error: ${sfResponse.status} ${errorText}`);
    }

    const data = await sfResponse.json();
    return NextResponse.json(data);
    
  } catch (error) {
    console.error('API Route Error:', error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
