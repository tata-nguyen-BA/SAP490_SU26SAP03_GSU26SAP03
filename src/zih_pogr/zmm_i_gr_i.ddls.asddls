@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'GR Upload - Item Interface'

define view entity zmm_i_gr_i
  as select from    zmm_tb_gr_i as gritem
    left outer join ekpo on  ekpo.ebeln = gritem.po_number
                         and ekpo.ebelp = gritem.po_item

  association to parent zmm_i_gr_h as _header on _header.GrNumber = $projection.GrNumber
{
  key gritem.gr_number         as GrNumber,
  key gritem.item              as Item,

      gritem.po_number         as PoNumber,
      gritem.po_item           as PoItem,
      ekpo.txz01               as PoItemText,


      gritem.material          as Material,
      gritem.plant             as Plant,

      gritem.receive_qty       as ReceiveQty,
      gritem.unit              as Unit,
      gritem.storage_location  as StorageLocation,

      gritem.order_qty         as OrderQty,
      gritem.open_qty          as OpenQty,

      gritem.status            as Status,
      case gritem.status
       when 'S' then 3
       when 'E' then 1
       else 2
      end                      as StatusCriticality,
      gritem.message           as Message,

      gritem.material_document as MaterialDocument,
      gritem.mat_doc_item      as MaterialDocumentItem,

      _header
}
