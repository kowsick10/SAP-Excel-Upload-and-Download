@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Parent Consumption View'
@Metadata.allowExtensions: true
define root view entity ZC_22CS083_USER
  provider contract transactional_query
  as projection on ZI_22CS083_USER
{
  key EmpID,
  key DevID,
      DevDescription,
      @Semantics.largeObject: {
          mimeType: 'Mimetype',
          fileName: 'Filename',
          acceptableMimeTypes: ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
          contentDispositionPreference: #ATTACHMENT
      }
      Attachment,
      Mimetype,
      Filename,
      FileStatus,
      Criticality,
      TemplateStatus,
      TemplateCriticality,
      LocalCreatedAt,
      LocalCreatedBy,
      LastChangedAt,
      _UserDev : redirected to composition child ZC_22CS083_USER_DEV
}
