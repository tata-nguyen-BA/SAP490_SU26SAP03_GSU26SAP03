@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Upload Batch - Interface'
@Metadata.ignorePropagatedAnnotations: true
define view entity zih_i_batch
  as select from zih_tb_batch
{
  key batch_id              as BatchId,

      process_id            as ProcessId,
      mapping_id            as MappingId,
      filename              as Filename,
      file_type             as FileType,
      testmode              as Testmode,

      status                as Status,
      case status
        when 'S' then 3
        when 'P' then 2
        when 'E' then 1
        else 0
      end                   as StatusCriticality,
      message               as Message,

      total_count           as TotalCount,
      success_count         as SuccessCount,
      error_count           as ErrorCount,
      log_handle            as LogHandle,

      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      created_by            as CreatedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt
}
