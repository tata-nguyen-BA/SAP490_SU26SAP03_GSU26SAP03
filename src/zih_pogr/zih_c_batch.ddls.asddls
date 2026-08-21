@EndUserText.label: 'Upload Batch Monitor'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define view entity zih_c_batch
  as select from zih_i_batch
{
  key BatchId,

      ProcessId,
      MappingId,
      Filename,
      FileType,
      Testmode,

      Status,
      StatusCriticality,
      Message,

      TotalCount,
      SuccessCount,
      ErrorCount,

      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LastChangedBy
}
