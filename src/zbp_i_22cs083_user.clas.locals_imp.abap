" ======================================================================
" 1. LOCAL CLASS DEFINITION
" ======================================================================
CLASS lhc_User DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR User RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR User RESULT result.

    METHODS uploadExcelData FOR MODIFY
      IMPORTING keys FOR ACTION User~uploadExcelData RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR User RESULT result.

    METHODS fillselectedstatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR User~fillselectedstatus.

    METHODS fillfilestatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR User~fillfilestatus.

    METHODS downloadExcel FOR MODIFY
      IMPORTING keys FOR ACTION User~downloadExcel RESULT result.
ENDCLASS.

" ======================================================================
" 2. LOCAL CLASS IMPLEMENTATION
" ======================================================================
CLASS lhc_User IMPLEMENTATION.

  " --- AUTHORIZATIONS ---
  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_authorizations.
    result = VALUE #( FOR key IN keys
                      ( %tky = key-%tky
                        %update = if_abap_behv=>auth-allowed
                        %delete = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  " --- INSTANCE FEATURES ---
  METHOD get_instance_features.
    READ ENTITIES OF zi_22cs083_user IN LOCAL MODE
      ENTITY User
      FIELDS ( FileStatus TemplateStatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_users).

    result = VALUE #( FOR user IN lt_users
      LET uploadBtn = COND #( WHEN user-FileStatus = 'File Selected'
                              THEN if_abap_behv=>fc-o-enabled
                              ELSE if_abap_behv=>fc-o-disabled )
          downloadBtn = COND #( WHEN user-TemplateStatus = 'Absent'
                                THEN if_abap_behv=>fc-o-enabled
                                ELSE if_abap_behv=>fc-o-disabled )
      IN ( %tky = user-%tky
           %action-uploadExcelData = uploadBtn
           %action-DownloadExcel   = downloadBtn ) ).
  ENDMETHOD.

  " --- DOWNLOAD TEMPLATE ---
  METHOD downloadExcel.
    DATA: lt_template TYPE STANDARD TABLE OF zbp_i_22cs083_user=>gty_exl_file.

    " Create Write Access
    DATA(lo_write_access) = xco_cp_xlsx=>document->empty( )->write_access( ).

    " FIX: Used 'worksheet->at_position( 1 )' to match your system's XCO version
    DATA(lo_worksheet) = lo_write_access->get_workbook( )->worksheet->at_position( 1 ).

    DATA(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'F' )
      )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
      )->get_pattern( ).

    lt_template = VALUE #( (
      emp_id   = 'User Id'
      dev_id   = 'Development Id'
      dev_desc = 'Development Description'
      obj_type = 'Object Type'
      obj_name = 'Object Name'
    ) ).

    lo_worksheet->select( lo_selection_pattern )->row_stream(
      )->operation->write_from( REF #( lt_template ) )->execute( ).

    DATA(lv_file_content) = lo_write_access->get_file_content( ).

    MODIFY ENTITIES OF zi_22cs083_user IN LOCAL MODE
      ENTITY User
      UPDATE FROM VALUE #( FOR ls_key IN keys (
        %tky       = ls_key-%tky
        Attachment = lv_file_content
        Filename   = 'template.xlsx'
        Mimetype   = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        %control-Attachment = if_abap_behv=>mk-on
        %control-Filename   = if_abap_behv=>mk-on
        %control-Mimetype   = if_abap_behv=>mk-on
      ) )
      REPORTED DATA(ls_reported).

    " Update Status
    MODIFY ENTITIES OF zi_22cs083_user IN LOCAL MODE
      ENTITY User
      UPDATE FIELDS ( FileStatus TemplateStatus )
      WITH VALUE #( FOR ls_key IN keys (
        %tky = ls_key-%tky
        FileStatus     = 'File not Selected'
        TemplateStatus = 'Present'
      ) ).

    READ ENTITIES OF zi_22cs083_user IN LOCAL MODE
      ENTITY User ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_updated_users).

    result = VALUE #( FOR ls_user IN lt_updated_users ( %tky = ls_user-%tky %param = ls_user ) ).
  ENDMETHOD.

  " --- UPLOAD EXCEL DATA ---
  METHOD uploadExcelData.
    DATA: lt_excel_temp TYPE STANDARD TABLE OF zbp_i_22cs083_user=>gty_exl_file,
          lt_excel      TYPE STANDARD TABLE OF zbp_i_22cs083_user=>gty_exl_file.

    READ ENTITIES OF zi_22cs083_user IN LOCAL MODE
      ENTITY User ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_file_entity).

    DATA(lv_attachment) = lt_file_entity[ 1 ]-Attachment.
    CHECK lv_attachment IS NOT INITIAL.

    TRY.
        DATA(lo_xlsx) = xco_cp_xlsx=>document->for_file_content( lv_attachment )->read_access( ).

        " FIX: Used 'worksheet->at_position( 1 )' here as well
        DATA(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).

        DATA(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).

        lo_worksheet->select( lo_selection_pattern )->row_stream(
          )->operation->write_to( REF #( lt_excel_temp )
          )->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
          )->execute( ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    DELETE lt_excel_temp INDEX 1.
    DELETE lt_excel_temp WHERE emp_id IS INITIAL AND dev_id IS INITIAL.

    lt_excel = lt_excel_temp.

    LOOP AT lt_excel ASSIGNING FIELD-SYMBOL(<lfs_excel>).
      <lfs_excel>-serial_no = sy-tabix.
    ENDLOOP.

    READ ENTITIES OF zi_22cs083_user IN LOCAL MODE
      ENTITY User BY \_UserDev
      FROM CORRESPONDING #( keys )
      RESULT DATA(lt_existing_UserDev).

    IF lt_existing_UserDev IS NOT INITIAL.
      MODIFY ENTITIES OF zi_22cs083_user IN LOCAL MODE
        ENTITY UserDev DELETE FROM VALUE #( FOR lwa_data IN lt_existing_UserDev ( %tky = lwa_data-%tky ) ).
    ENDIF.

    DATA lt_data TYPE TABLE FOR CREATE zi_22cs083_user\_UserDev.

    LOOP AT lt_file_entity INTO DATA(ls_parent).
      APPEND VALUE #(
        %tky = ls_parent-%tky
        %target = VALUE #( FOR lwa_excel IN lt_excel (
            %cid       = |CID_{ lwa_excel-serial_no }|
            EmpId      = ls_parent-EmpId
            DevId      = ls_parent-DevId
            SerialNo   = lwa_excel-serial_no
            ObjectType = lwa_excel-obj_type
            ObjectName = lwa_excel-obj_name
            %control   = VALUE #( EmpId = if_abap_behv=>mk-on DevId = if_abap_behv=>mk-on SerialNo = if_abap_behv=>mk-on ObjectType = if_abap_behv=>mk-on ObjectName = if_abap_behv=>mk-on )
        ) )
      ) TO lt_data.
    ENDLOOP.

    IF lt_data IS NOT INITIAL.
      MODIFY ENTITIES OF zi_22cs083_user IN LOCAL MODE
        ENTITY User CREATE BY \_UserDev FROM lt_data.
    ENDIF.

    MODIFY ENTITIES OF zi_22cs083_user IN LOCAL MODE
      ENTITY User
      UPDATE FIELDS ( FileStatus )
      WITH VALUE #( FOR ls_key IN keys ( %tky = ls_key-%tky FileStatus = 'Excel Uploaded' ) ).

    READ ENTITIES OF zi_22cs083_user IN LOCAL MODE
      ENTITY User ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_updated_User).

    result = VALUE #( FOR lwa_upd_head IN lt_updated_User ( %tky = lwa_upd_head-%tky %param = lwa_upd_head ) ).
  ENDMETHOD.

  " --- DETERMINATIONS ---
  METHOD fillFileStatus.
    READ ENTITIES OF zi_22cs083_user IN LOCAL MODE
      ENTITY User FIELDS ( FileStatus TemplateStatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_user).

    MODIFY ENTITIES OF zi_22cs083_user IN LOCAL MODE
      ENTITY User
      UPDATE FIELDS ( FileStatus TemplateStatus )
      WITH VALUE #( FOR ls_user IN lt_user (
        %tky           = ls_user-%tky
        FileStatus     = 'File not Selected'
        TemplateStatus = 'Absent'
      ) ).
  ENDMETHOD.

  METHOD fillSelectedStatus.
    READ ENTITIES OF zi_22cs083_user IN LOCAL MODE
      ENTITY User FIELDS ( Attachment ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_user).

    MODIFY ENTITIES OF zi_22cs083_user IN LOCAL MODE
      ENTITY User
      UPDATE FIELDS ( FileStatus )
      WITH VALUE #( FOR ls_user IN lt_user (
        %tky       = ls_user-%tky
        FileStatus = COND #( WHEN ls_user-Attachment IS INITIAL THEN 'File not Selected' ELSE 'File Selected' )
      ) ).
  ENDMETHOD.

ENDCLASS.
