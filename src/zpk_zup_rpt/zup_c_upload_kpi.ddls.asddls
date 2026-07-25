@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Upload KPI - GR + FI + PP'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZUP_C_UPLOAD_KPI
  as select from zmm_tb_gr_h as GR
{
  key cast( 'GR' as abap.char( 2 ) )          as DocType,
  key cast( GR.gr_number as abap.char( 50 ) ) as DocId,
      cast( GR.batch_id as abap.char( 255 ) ) as BatchId,
      GR.status                               as Status,
      cast( '' as abap.char( 255 ) )          as Message,
      GR.created_by                           as CreatedBy,
      GR.document_date                        as DocDate,
//      @DefaultAggregation: #AVG
//      cast( case
//              when GR.status = 'S' or GR.status = 'E'
//              
//              then utcl_seconds_between( GR.created_at, GR.last_changed_at )
//              else 0
//            end as abap.int4 )                as ProcessingSeconds,
            
       @DefaultAggregation: #AVG
      cast( case
              when GR.status = 'S' or GR.status = 'E'
              then utcl_seconds_between( GR.created_at, GR.last_changed_at)
              else 0
            end as abap.int8 )                as ProcessingSeconds,
      @DefaultAggregation: #SUM
      cast( 1 as abap.int4 )                  as RecordCount
}
union all select from zfi_tb_upload as FI
{
  key cast( 'FI' as abap.char( 2 ) )          as DocType,
  key cast( FI.id_doc as abap.char( 50 ) )    as DocId,
      cast( FI.filename as abap.char( 255 ) ) as BatchId,
      cast( 'S' as abap.char( 1 ) )           as Status,
      cast( '' as abap.char( 255 ) )          as Message,
      FI.pst_user                             as CreatedBy,
      FI.pst_date                             as DocDate,
      cast( 0 as abap.int8 )                  as ProcessingSeconds,
      cast( 1 as abap.int4 )                  as RecordCount
}
union all select from zpp_tb_zuplsx as PP
{
  key cast( 'PP' as abap.char( 2 ) )          as DocType,
  key cast( PP.iddoc as abap.char( 50 ) )     as DocId,
      cast( PP.filename as abap.char( 255 ) ) as BatchId,
      cast( 'S' as abap.char( 1 ) )           as Status,
      cast( '' as abap.char( 255 ) )          as Message,
      PP.pst_user                             as CreatedBy,
      PP.pst_date                             as DocDate,
      cast( 0 as abap.int8 )                  as ProcessingSeconds,
      cast( 1 as abap.int4 )                  as RecordCount
}
union all select from ztb_upload_err as ERR
{
  key cast( ERR.doc_type as abap.char( 2 ) )  as DocType,
  key cast( ERR.id_doc as abap.char( 50 ) )   as DocId,
      cast( ERR.filename as abap.char( 255 ) ) as BatchId,
      cast( 'E' as abap.char( 1 ) )           as Status,
      cast( '' as abap.char( 255 ) )          as Message,
      ERR.created_by                          as CreatedBy,
      ERR.log_date                            as DocDate,
      cast( 0 as abap.int8 )                  as ProcessingSeconds,
      cast( 1 as abap.int4 )                  as RecordCount
}
