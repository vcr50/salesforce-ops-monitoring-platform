# SentinelFlow Keyset Pagination Architecture Plan (Milestone 51A)

**Date**: 2026-05-29  
**Author**: TomCodeX Engineering  
**Status**: Proposal  
**Version**: 1.0  

---

## 1. Purpose

The purpose of this architecture plan is to transition the SentinelFlow Incident Command Center from an Offset-Based pagination model to a high-performance **Keyset (Cursor-Based) Pagination** model. This shift will enable the Incident Board to load and query database records infinitely and securely under large-volume production conditions, completely bypassing the Salesforce SOQL OFFSET governor limits.

---

## 2. Why OFFSET Pagination is Limited

Salesforce SOQL imposes strict limits on OFFSET query clauses:
*   **The 2,000-Record Ceiling**: Any query executing with an `OFFSET` parameter greater than `2,000` records throws a `MALFORMED_QUERY` exception.
*   **Performance Degradation**: At scale, databases must scan all records preceding the offset to locate and return the desired page. An offset query on row 1,950 requires scanning 2,000 records, discarding 1,950, and returning the remaining 50. This creates linear performance degradation under heavy data loads.

---

## 3. Keyset Pagination Strategy

Unlike offset pagination which instructs the database engine to skip a count of records, **keyset pagination** works by querying records relative to a specific boundary point (a "cursor").
*   The query specifies sorting fields and orders.
*   Instead of using `OFFSET`, the query appends a `WHERE` condition that selects only records that are strictly "before" or "after" the cursor value in the sorted order.
*   Because the database can perform index scans directly from the cursor boundary, query execution remains constant ($O(1)$) regardless of the depth of the pagination.

---

## 4. Cursor Fields: `CreatedDate` + `Id`

To guarantee unique, deterministic sorting and paging, keyset pagination requires a compound cursor composed of:
1.  **CreatedDate** (Datetime): The primary sorting field. While highly monotonic, multiple records can share the exact same milliseconds (especially under bulk API imports).
2.  **Id** (Id): The secondary sorting field. Since record IDs are globally unique, they resolve any ordering conflicts when `CreatedDate` values match.

---

## 5. Forward Pagination Design

When paginating forward ("Next Page") under default `CreatedDate DESC` sorting, we want to fetch the subsequent `pageSize` records that are older than the last record on the active page.

```
Active Page Last Record: (CreatedDate = T_last, Id = Id_last)
```

To fetch older records, the query uses:
```sql
SELECT ... FROM Sentinel_Incident__c
WHERE (CreatedDate < :cursorCreatedDate) 
   OR (CreatedDate = :cursorCreatedDate AND Id < :cursorId)
ORDER BY CreatedDate DESC, Id DESC
LIMIT :pageSize
```

---

## 6. Backward Pagination Design

When paginating backward ("Previous Page") under `CreatedDate DESC` sorting, we want to retrieve the immediately preceding `pageSize` records that are newer than the first record on the active page.

```
Active Page First Record: (CreatedDate = T_first, Id = Id_first)
```

To fetch newer records, we query:
```sql
SELECT ... FROM Sentinel_Incident__c
WHERE (CreatedDate > :cursorCreatedDate) 
   OR (CreatedDate = :cursorCreatedDate AND Id > :cursorId)
ORDER BY CreatedDate ASC, Id ASC
LIMIT :pageSize
```

> [!IMPORTANT]  
> Because querying backward requires sorting in the opposite order (`ASC, ASC`), the database returns records in ascending sequence. After fetching, the Apex controller must **reverse the list in-memory** before returning the results to restore the user's expected descending sorting order (`DESC, DESC`).

---

## 7. Sort Compatibility

For v1.2.0, the keyset pagination model will support sorting by the primary indexed field:
*   `CreatedDate`: Default and most common operational incident ordering.

If the operator selects other whitelisted columns (e.g. `Incident_Type__c`, `Status__c`), the system will dynamically fall back to the **Offset-Based** query (capped at 2,000 records). Since sorting by non-CreatedDate columns is typically performed on filtered, smaller operational slices, this fallback satisfies governor limits safely.

---

## 8. Filter Compatibility

All operational dashboard filters (Risk Level, Status, Environment, AI Status, Type, and Date Range) are fully compatible with keyset pagination:
1.  Filters are appended to the SOQL `WHERE` clause as bind variables.
2.  The keyset condition is combined with these filters using an `AND` operator:
    ```sql
    WHERE (Risk_Level__c = :riskLevel AND Environment__c = :environment)
      AND ((CreatedDate < :cursorDate) OR (CreatedDate = :cursorDate AND Id < :cursorId))
    ```

---

## 9. LWC Cursor State

In the Lightning Web Component (`zentomDashboard.js`), page numbering calculations are updated to manage cursor tracking variables:

```javascript
// State properties
nextCursorCreatedDate = null;
nextCursorId = null;
previousCursorCreatedDate = null;
previousCursorId = null;
pageDirection = null; // 'NEXT' or 'PREV'
```

### Navigation Rules
*   **Next Page**:
    *   Set `pageDirection = 'NEXT'`.
    *   Set cursor variables to the values of the last record in the current list.
*   **Previous Page**:
    *   Set `pageDirection = 'PREV'`.
    *   Set cursor variables to the values of the first record in the current list.
*   **Filter/Sort/Page Size Reset**:
    *   Clear all cursors (`null`) to reset queries to page 1.

---

## 10. Governor Safety

The keyset model ensures high safety metrics:
*   **Heap Size**: Limited strictly to `pageSize` records in memory.
*   **Query Rows**: Fetches only `pageSize` rows, keeping transactions well below the 50,000 SOQL row limit.
*   **Index Utilization**: The dynamic SOQL uses the standard index on `CreatedDate` and `Id`, preventing full table scans.

---

## 11. Migration Plan from OFFSET

To ensure complete business continuity and zero-downtime operations:
1.  **Do not deprecate Milestone 50 queries immediately**. Keep the `getPaginatedIncidents()` offset method in `ZentomDashboardController.cls` as a fallback.
2.  Introduce `getKeysetPaginatedIncidents()` as a new endpoint.
3.  Deploy and validate keyset pagination in LWC, falling back gracefully to offset queries if a client errors or requests sorting on custom nullable columns.

---

## 12. Success Criteria

- [x] Successful compilation and deployment of `docs/keyset-pagination-architecture-plan.md`.
- [x] No regression on existing platform event or streaming operations.
- [x] Keyset queries executed correctly without `OFFSET` keyword usage.
- [x] Unit tests validate 100% coverage on keyset boundaries.
