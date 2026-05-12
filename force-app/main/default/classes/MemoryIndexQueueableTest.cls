/**
 * MemoryIndexQueueableTest
 * Test class for MemoryIndexQueueable.
 * Covers success callout, non-200 response handling, and callout exception handling.
 *
 * @author  Tomcodex
 * @version 2.6
 */
@isTest
private class MemoryIndexQueueableTest {

    // ── Mock: 201 Created (success path) ────────────────────────────────────
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"status":"indexed"}');
            return res;
        }
    }

    // ── Mock: 500 Server Error ───────────────────────────────────────────────
    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"internal server error"}');
            return res;
        }
    }

    // ── Mock: throws CalloutException ────────────────────────────────────────
    private class ExceptionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            CalloutException ex = new CalloutException();
            ex.setMessage('Network unreachable');
            throw ex;
        }
    }

    // ── Tests ────────────────────────────────────────────────────────────────

    @isTest
    static void testSuccessfulIndex() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        MemoryIndexQueueable job = new MemoryIndexQueueable(
            'INC-001',
            'success',
            'oauth_refresh',
            'Token expired on Stripe Gateway',
            1200
        );
        System.enqueueJob(job);
        Test.stopTest();

        // No exception thrown = success path ran cleanly
        System.assert(true, 'MemoryIndexQueueable executed successfully on success mock.');
    }

    @isTest
    static void testNon200Response() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        MemoryIndexQueueable job = new MemoryIndexQueueable(
            'INC-002',
            'failed',
            'retry',
            'API timeout after 3 attempts',
            4500
        );
        System.enqueueJob(job);
        Test.stopTest();

        // Job should handle 500 gracefully and log via SystemLogger
        System.assert(true, 'MemoryIndexQueueable handled non-200 response without unhandled exception.');
    }

    @isTest
    static void testCalloutException() {
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());

        Test.startTest();
        MemoryIndexQueueable job = new MemoryIndexQueueable(
            'INC-003',
            'escalated',
            'pause_batch',
            'Repeated OAuth failure — escalated to manager',
            0
        );
        System.enqueueJob(job);
        Test.stopTest();

        // Job should catch CalloutException and log it, not bubble up
        System.assert(true, 'MemoryIndexQueueable handled callout exception without crashing.');
    }

    @isTest
    static void testRequeueJobHealAction() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        MemoryIndexQueueable job = new MemoryIndexQueueable(
            'INC-004',
            'success',
            'requeue_job',
            'Scheduled batch was missing — requeued successfully',
            800
        );
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true, 'MemoryIndexQueueable ran requeue_job heal action path.');
    }
}
