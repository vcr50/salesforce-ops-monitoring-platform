const formatSalesforceRecord = (record) => {
  if (!record) return null;

  return {
    id: record.Id,
    attributes: record.attributes,
    data: Object.fromEntries(
      Object.entries(record)
        .filter(([key]) => key !== 'Id' && key !== 'attributes')
    ),
    createdDate: record.CreatedDate,
    lastModifiedDate: record.LastModifiedDate
  };
};

const formatSalesforceError = (error) => {
  if (Array.isArray(error)) {
    return error.map(err => ({
      message: err.message,
      errorCode: err.errorCode,
      fields: err.fields || []
    }));
  }

  return {
    message: error.message || 'Unknown error',
    errorCode: error.errorCode || 'UNKNOWN'
  };
};

const formatBulkJobResult = (result) => {
  return {
    jobId: result.id,
    state: result.state,
    numberBatchesQueued: result.numberBatchesQueued,
    numberBatchesInProgress: result.numberBatchesInProgress,
    numberBatchesCompleted: result.numberBatchesCompleted,
    numberBatchesFailed: result.numberBatchesFailed,
    totalProcessingTime: result.totalProcessingTime
  };
};

module.exports = {
  formatSalesforceRecord,
  formatSalesforceError,
  formatBulkJobResult
};
