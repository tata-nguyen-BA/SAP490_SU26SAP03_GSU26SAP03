@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Upload KPI - GR + FI + PP'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true

define view entity ZUP_C_UPLOAD_KPI
  as select from zmm_tb_gr_h as GR
{
      // GR_NUMBER là key của bảng -> tự nó đã duy nhất
  key cast( 'GR' as abap.char( 2 ) )          as Source,
  key cast( GR.batch_id as abap.char( 255 ) ) as BatchId,
  key cast( GR.gr_number as abap.char( 50 ) ) as DocId,

      cast( 'GR' as abap.char( 2 ) )          as DocType,
      // Số chứng từ nghiệp vụ để hiển thị. Rỗng khi chưa post xong.
      cast( GR.material_document as abap.char( 20 ) ) as DocNumber,
      GR.status                               as Status,
      cast( '' as abap.char( 255 ) )          as Message,
      GR.created_by                           as CreatedBy,
      GR.document_date                        as DocDate,

      @DefaultAggregation: #AVG
      cast( case
              when GR.status = 'S' or GR.status = 'E'
              then utcl_seconds_between( GR.created_at, GR.last_changed_at )
              else 0
            end as abap.int8 )                as ProcessingSeconds,

      @DefaultAggregation: #SUM
      cast( 1 as abap.int4 )                  as RecordCount
}

union all select from zfi_tb_upload as FI
{
      // FILENAME + ID_DOC = đúng key của bảng
  key cast( 'FI' as abap.char( 2 ) )          as Source,
  key cast( FI.filename as abap.char( 255 ) ) as BatchId,
  key cast( FI.id_doc as abap.char( 50 ) )    as DocId,

      cast( 'FI' as abap.char( 2 ) )          as DocType,
      // Số chứng từ kế toán SAP cấp. ID_DOC ở trên chỉ là số thứ tự trong file.
      cast( FI.accountingdocument as abap.char( 20 ) ) as DocNumber,
      cast( 'S' as abap.char( 1 ) )           as Status,
      cast( '' as abap.char( 255 ) )          as Message,
      FI.pst_user                             as CreatedBy,
      FI.pst_date                             as DocDate,
      cast( 0 as abap.int8 )                  as ProcessingSeconds,
      cast( 1 as abap.int4 )                  as RecordCount
}

union all select from zpp_tb_zuplsx as PP
{
      // PRODUCTIONORDER nằm trong key bảng và là số lệnh SAP cấp
      // -> duy nhất. IDDOC chỉ là số thứ tự dòng trong file, KHÔNG dùng làm key.
  key cast( 'PP' as abap.char( 2 ) )          as Source,
  key cast( PP.filename as abap.char( 255 ) ) as BatchId,
  key cast( PP.productionorder as abap.char( 50 ) ) as DocId,

      cast( 'PP' as abap.char( 2 ) )          as DocType,
      cast( PP.productionorder as abap.char( 20 ) ) as DocNumber,
      cast( 'S' as abap.char( 1 ) )           as Status,
      cast( '' as abap.char( 255 ) )          as Message,
      PP.pst_user                             as CreatedBy,
      PP.pst_date                             as DocDate,
      cast( 0 as abap.int8 )                  as ProcessingSeconds,
      cast( 1 as abap.int4 )                  as RecordCount
}

union all select from ztb_upload_err as ERR
{
      // LOG_ID là key của bảng. Một chứng từ có thể sinh NHIỀU dòng lỗi,
      // nên không được dùng ID_DOC làm key.
  key cast( 'ER' as abap.char( 2 ) )          as Source,
  key cast( ERR.filename as abap.char( 255 ) ) as BatchId,
  key cast( ERR.log_id as abap.char( 50 ) )   as DocId,

      cast( ERR.doc_type as abap.char( 2 ) )  as DocType,
      // Dòng lỗi thì chưa có số chứng từ nào được cấp
      cast( '' as abap.char( 20 ) )           as DocNumber,
      cast( 'E' as abap.char( 1 ) )           as Status,

      // KHÔNG cast được ERR.message: field này khai kiểu STRG (abap.string),
      // mà CAST trong CDS chỉ nhận ACCP CHAR CLNT CUKY LANG RAW UNIT NUMC DEC INT...
      // Union cũng bắt buộc 4 nhánh cùng kiểu, nên giữ hằng rỗng như 3 nhánh kia.
      // Muốn hiện nội dung lỗi thì xem ghi chú cuối file.
      cast( '' as abap.char( 255 ) )          as Message,
      ERR.created_by                          as CreatedBy,
      ERR.log_date                            as DocDate,
      cast( 0 as abap.int8 )                  as ProcessingSeconds,
      cast( 1 as abap.int4 )                  as RecordCount
}

