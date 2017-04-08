create or replace
package body dev_utl
as

  /**
   * This package provides some APIs for developer needs
   *
   * @author Mike Mulev (mailto:m.mulev@gmail.com)
   */

  --

  /**
   * Get name for TAPI package
   *
   * @param p_table_name target table name
   *
   * @return package name
   */
  function get_tapi_name
  (
    p_table_name in varchar2
  )
  return varchar2
  as
  begin
    return substr(lower(p_table_name), 1, 25) || '_tapi';
  end;

  /**
   * Get list of non PK columns
   *
   * @param p_schema_name table schema name
   * @param p_table_name target table name
   *
   * @return list of table columns
   */
  function get_not_pk_columns
  (
    p_schema_name in varchar2,
    p_table_name  in varchar2
  )
  return strings
  as
    l_columns strings := strings();
    --
    cursor cols is
      select    lower(column_name)
      from      all_tab_columns
      where     owner = upper(p_schema_name)
      and       table_name = upper(p_table_name)
      and       column_name not in (
                  select  column_name
                  from    all_cons_columns
                  where   owner = upper(p_schema_name)
                  and     constraint_name in (
                            select  constraint_name
                            from    all_constraints
                            where   owner = upper(p_schema_name)
                            and     table_name = upper(p_table_name)
                            and     constraint_type = 'P'
                          )
                  and     table_name = upper(p_table_name)
                )
      order by  column_id;
  begin
    open cols;
    fetch cols bulk collect into l_columns;
    close cols;

    return l_columns;
  end;

  /**
   * Get PK column name
   *
   * @param p_schema_name table schema name
   * @param p_table_name target table name
   *
   * @return PK column name
   */
  function get_pk_column
  (
    p_schema_name in varchar2,
    p_table_name  in varchar2
  )
  return varchar2
  as
    l_column varchar2(30);
  begin
    select  column_name
    into    l_column
    from    all_cons_columns
    where   owner = upper(p_schema_name)
    and     constraint_name in (
              select  constraint_name
              from    all_constraints
              where   owner = upper(p_schema_name)
              and     table_name = upper(p_table_name)
              and     constraint_type = 'P'
            )
    and     table_name = upper(p_table_name);

    return l_column;
  end;

  /**
   * Get length of longest column in table
   *
   * @param p_columns list of table columns
   *
   * @return column length
   */
  function longest_column_length
  (
    p_columns in strings
  )
  return number
  as
    l_length number;
  begin
    select  max(length(column_value))
    into    l_length
    from    table(p_columns);

    return l_length;
  end;

  /**
   * Get length of longest column in table
   *
   * @param p_first_column first column name
   * @param p_second_column second column name
   *
   * @return column length
   */
  function longest_column_length
  (
    p_first_column  in varchar2,
    p_second_column in varchar2
  )
  return number
  as
    l_length number;
  begin
    if length(p_first_column) > length(p_second_column) then
      l_length := length(p_first_column);
    else
      l_length := length(p_second_column);
    end if;

    return l_length;
  end;

  /**
   * Make variable name from column
   *
   * @param p_column table column name
   * @param p_prefix variable prefix
   *
   * @return variable name
   */
  function variable_from_column
  (
    p_column  in varchar2,
    p_prefix  in varchar2
  )
  return varchar2
  as
  begin
    return p_prefix || substr(lower(p_column), 1, 30 - length(p_prefix));
  end;

  /**
   * Get spaces for declarations
   *
   * @param p_var variable name
   * @param p_max_length length of longest variable
   *
   * @return string with spaces
   */
  function get_spaces
  (
    p_var         in varchar2,
    p_max_length  in number
  )
  return varchar2
  as
    l_cnt     number;
    l_spaces  varchar2(30) := ' ';
  begin
    l_cnt := p_max_length + 3 - length(p_var);
    --
    for i in 1 .. l_cnt
    loop
      l_spaces := l_spaces || ' ';
    end loop;
    --
    return l_spaces;
  end;

  /**
   * Construct table insert function spec
   *
   * @param p_table_name table name
   * @param p_pk_column PK column name
   * @param p_columns list of non PK table columns
   *
   * @return table insert function spec
   */
  function make_insert_spec
  (
    p_table_name  in varchar2,
    p_pk_column   in varchar2,
    p_columns     in strings
  )
  return varchar2
  as
    l_sql             varchar2(32767) := '';
    l_var             varchar2(30);
    l_max_col_length  number          := longest_column_length(p_columns);
  begin
    l_sql := l_sql || '  -- Insert new row in target table' || chr(10);
    --
    l_sql := l_sql || '  function insert_row' || chr(10);
    l_sql := l_sql || '  (' || chr(10);
    --
    for i in 1 .. p_columns.count
    loop
      l_var := variable_from_column(p_columns(i), 'p_');
      l_sql := l_sql || '    ' || l_var || get_spaces(l_var, l_max_col_length);
      l_sql := l_sql || 'in      ' || lower(p_table_name) || '.';
      l_sql := l_sql || lower(p_columns(i)) || '%type,' || chr(10);
    end loop;
    --
    l_var := 'p_error';
    l_sql := l_sql || '    ' || l_var || get_spaces(l_var, l_max_col_length);
    l_sql := l_sql || 'in  out error_obj' || chr(10);
    l_sql := l_sql || '  )' || chr(10);
    l_sql := l_sql || '  return ' || lower(p_table_name) || '.';
    l_sql := l_sql || lower(p_pk_column) || '%type';
    --
    return l_sql;
  end;

  /**
   * Construct table update procedure spec
   *
   * @param p_table_name table name
   * @param p_pk_column PK column name
   * @param p_columns list of non PK table columns
   *
   * @return table update procedure spec
   */
  function make_update_spec
  (
    p_table_name  in varchar2,
    p_pk_column   in varchar2,
    p_columns     in strings
  )
  return varchar2
  as
    l_sql             varchar2(32767) := '';
    l_var             varchar2(30);
    l_max_col_length  number          := longest_column_length(p_columns);
  begin
    l_sql := l_sql || '  -- Update row in target table' || chr(10);
    --
    l_sql := l_sql || '  procedure update_row' || chr(10);
    l_sql := l_sql || '  (' || chr(10);
    --
    l_var := variable_from_column(p_pk_column, 'p_');
    l_sql := l_sql || '    ' || l_var || get_spaces(l_var, l_max_col_length);
    l_sql := l_sql || 'in      ' || lower(p_table_name) || '.';
    l_sql := l_sql || lower(p_pk_column) || '%type,' || chr(10);
    --
    for i in 1 .. p_columns.count
    loop
      l_var := variable_from_column(p_columns(i), 'p_');
      l_sql := l_sql || '    ' || l_var || get_spaces(l_var, l_max_col_length);
      l_sql := l_sql || 'in      ' || lower(p_table_name) || '.';
      l_sql := l_sql || lower(p_columns(i)) || '%type';
      l_sql := l_sql || get_spaces(l_var, l_max_col_length) || 'default null,';
      l_sql := l_sql || chr(10);
    end loop;
    --
    l_var := 'p_error';
    l_sql := l_sql || '    ' || l_var || get_spaces(l_var, l_max_col_length);
    l_sql := l_sql || 'in  out error_obj' || chr(10);
    l_sql := l_sql || '  )';
    --
    return l_sql;
  end;

  /**
   * Construct table delete procedure spec
   *
   * @param p_table_name table name
   * @param p_pk_column PK column name
   *
   * @return table delete procedure spec
   */
  function make_delete_spec
  (
    p_table_name  in varchar2,
    p_pk_column   in varchar2
  )
  return varchar2
  as
    l_sql             varchar2(32767) := '';
    l_var             varchar2(30);
    l_max_col_length  number          := 8;
  begin
    l_sql := l_sql || '  -- Delete row from target table' || chr(10);
    --
    l_sql := l_sql || '  procedure delete_row' || chr(10);
    l_sql := l_sql || '  (' || chr(10);
    --
    l_var := variable_from_column(p_pk_column, 'p_');
    l_sql := l_sql || '    ' || l_var || get_spaces(l_var, l_max_col_length);
    l_sql := l_sql || 'in      ' || lower(p_table_name) || '.';
    l_sql := l_sql || lower(p_pk_column) || '%type,' || chr(10);
    --
    l_var := 'p_error';
    l_sql := l_sql || '    ' || l_var || get_spaces(l_var, l_max_col_length);
    l_sql := l_sql || 'in  out error_obj' || chr(10);
    l_sql := l_sql || '  )';
    --
    return l_sql;
  end;

  /**
   * Construct table column getter spec
   *
   * @param p_table_name table name
   * @param p_pk_column PK column name
   * @param p_column target table column
   *
   * @return table column getter spec
   */
  function make_getter_spec
  (
    p_table_name  in varchar2,
    p_pk_column   in varchar2,
    p_column      in varchar2
  )
  return varchar2
  as
    l_sql varchar2(32767) := '';
    l_var varchar2(30);
  begin
    l_sql := l_sql || '  -- Get ' || lower(p_column);
    l_sql := l_sql || ' column value' || chr(10);
    --
    l_sql := l_sql || '  function ' || lower(p_column) || chr(10);
    l_sql := l_sql || '  (' || chr(10);
    --
    l_var := variable_from_column(p_pk_column, 'p_');
    l_sql := l_sql || '    ' || l_var || ' in ' || lower(p_table_name) || '.';
    l_sql := l_sql || lower(p_pk_column) || '%type' || chr(10);
    --
    l_sql := l_sql || '  )' || chr(10);
    l_sql := l_sql || '  return ' || lower(p_table_name) || '.';
    l_sql := l_sql || lower(p_column) || '%type';
    --
    return l_sql;
  end;

  /**
   * Construct table column setter spec
   *
   * @param p_table_name table name
   * @param p_pk_column PK column name
   * @param p_column target table column
   *
   * @return table column setter spec
   */
  function make_setter_spec
  (
    p_table_name  in varchar2,
    p_pk_column   in varchar2,
    p_column      in varchar2
  )
  return varchar2
  as
    l_sql             varchar2(32767) := '';
    l_var             varchar2(30);
    l_max_col_length  number;
  begin
    l_max_col_length := longest_column_length(p_pk_column, p_column);
    if l_max_col_length < length('p_error') then
      l_max_col_length := length('p_error');
    end if;
    --
    l_sql := l_sql || '  -- Set new value for ' || lower(p_column);
    l_sql := l_sql || ' column' || chr(10);
    --
    l_sql := l_sql || '  procedure ' || lower(p_column) || chr(10);
    l_sql := l_sql || '  (' || chr(10);
    --
    l_var := variable_from_column(p_pk_column, 'p_');
    l_sql := l_sql || '    ' || l_var || get_spaces(l_var, l_max_col_length);
    l_sql := l_sql || 'in      ' || lower(p_table_name) || '.';
    l_sql := l_sql || lower(p_pk_column) || '%type,' || chr(10);
    --
    l_var := variable_from_column(p_column, 'p_');
    l_sql := l_sql || '    ' || l_var || get_spaces(l_var, l_max_col_length);
    l_sql := l_sql || 'in      ' || lower(p_table_name) || '.';
    l_sql := l_sql || lower(p_column) || '%type,' || chr(10);
    --
    l_var := 'p_error';
    l_sql := l_sql || '    ' || l_var || get_spaces(l_var, l_max_col_length);
    l_sql := l_sql || 'in  out error_obj' || chr(10);
    l_sql := l_sql || '  )';
    --
    return l_sql;
  end;

  /**
   * Construct TAPI package spec
   *
   * @param p_schema_name table schema name
   * @param p_table_name target table name
   *
   * @return package spec
   */
  function make_tapi_spec
  (
    p_schema_name in varchar2,
    p_table_name  in varchar2
  )
  return varchar2
  as
    l_spec            varchar2(32767);
    l_name            varchar2(30)    := get_tapi_name(p_table_name);
    l_pk_column       varchar2(30);
    l_non_pk_columns  strings;
  begin
    l_spec := 'create or replace' || chr(10);
    l_spec := l_spec || 'package ' || lower(p_schema_name);
    l_spec := l_spec || '.' || l_name || chr(10);
    l_spec := l_spec || 'as' || chr(10) || chr(10);
    --
    l_pk_column := get_pk_column(p_schema_name, p_table_name);
    l_non_pk_columns := get_not_pk_columns(p_schema_name, p_table_name);
    --
    for i in 1 .. l_non_pk_columns.count
    loop
      l_spec := l_spec || make_getter_spec(
        p_table_name,
        l_pk_column,
        l_non_pk_columns(i)
      );
      l_spec := l_spec || ';' || chr(10) || chr(10);
      l_spec := l_spec || make_setter_spec(
        p_table_name,
        l_pk_column,
        l_non_pk_columns(i)
      );
      l_spec := l_spec || ';' || chr(10) || chr(10);
    end loop;
    --
    l_spec := l_spec || make_insert_spec(
      p_table_name,
      l_pk_column,
      l_non_pk_columns
    );
    l_spec := l_spec || ';' || chr(10) || chr(10);
    l_spec := l_spec || make_update_spec(
      p_table_name,
      l_pk_column,
      l_non_pk_columns
    );
    l_spec := l_spec || ';' || chr(10) || chr(10);
    l_spec := l_spec || make_delete_spec(
      p_table_name,
      l_pk_column
    );
    l_spec := l_spec || ';' || chr(10) || chr(10);
    --
    l_spec := l_spec || 'end ' || l_name || ';' || chr(10);
    --
    return l_spec;
  end;

  /**
   * Construct table insert function body
   *
   * @param p_table_name table name
   * @param p_pk_column PK column name
   * @param p_columns list of non PK table columns
   *
   * @return table insert function body
   */
  function make_insert_body
  (
    p_table_name  in varchar2,
    p_pk_column   in varchar2,
    p_columns     in strings
  )
  return varchar2
  as
    l_sql varchar2(32767) := '';
    l_var varchar2(30);
  begin
    l_sql := l_sql || make_insert_spec(
      p_table_name,
      p_pk_column,
      p_columns
    );
    l_sql := l_sql || chr(10);
    --
    l_sql := l_sql || '  as' || chr(10);
    l_var := variable_from_column(p_pk_column, 'l_');
    l_sql := l_sql || '    ' || l_var || ' ' || lower(p_table_name);
    l_sql := l_sql || '.' || lower(p_pk_column) || '%type;' || chr(10);
    --
    l_sql := l_sql || '  begin' || chr(10);
    l_sql := l_sql || '    insert into ' || lower(p_table_name) || '(' || chr(10);

    for i in 1 .. p_columns.count
    loop
      l_sql := l_sql || '      ' || lower(p_columns(i));
      if i < p_columns.count then
        l_sql := l_sql || ',';
      end if;
      l_sql := l_sql || chr(10);
    end loop;

    l_sql := l_sql || '    ) values (' || chr(10);

    for i in 1 .. p_columns.count
    loop
      l_var := variable_from_column(p_columns(i), 'p_');
      l_sql := l_sql || '      ' || l_var;
      if i < p_columns.count then
        l_sql := l_sql || ',';
      end if;
      l_sql := l_sql || chr(10);
    end loop;

    l_sql := l_sql || '    ) returning ' || lower(p_pk_column) || ' into ';
    l_var := variable_from_column(p_pk_column, 'l_');
    l_sql := l_sql || l_var || ';' || chr(10) || chr(10);
    l_sql := l_sql || '    return ' || l_var || ';' || chr(10);
    l_sql := l_sql || '  exception' || chr(10);
    l_sql := l_sql || '    when others then' || chr(10);
    l_sql := l_sql || '      p_error.fix;' || chr(10);
    l_sql := l_sql || '      ' || chr(10);
    l_sql := l_sql || '      return null;' || chr(10);
    l_sql := l_sql || '  end';
    --
    return l_sql;
  end;

  /**
   * Construct table update procedure body
   *
   * @param p_table_name table name
   * @param p_pk_column PK column name
   * @param p_columns list of non PK table columns
   *
   * @return table update procedure body
   */
  function make_update_body
  (
    p_table_name  in varchar2,
    p_pk_column   in varchar2,
    p_columns     in strings
  )
  return varchar2
  as
    l_sql             varchar2(32767) := '';
    l_var             varchar2(30);
    l_max_col_length  number          := longest_column_length(p_columns);
  begin
    l_sql := l_sql || make_update_spec(
      p_table_name,
      p_pk_column,
      p_columns
    );
    l_sql := l_sql || chr(10);
    --
    l_sql := l_sql || '  as' || chr(10);
    --
    for i in 1 .. p_columns.count
    loop
      l_var := variable_from_column(p_columns(i), 'l_');
      l_sql := l_sql || '    ' || l_var || get_spaces(l_var, l_max_col_length);
      l_sql := l_sql || lower(p_table_name) || '.' || p_columns(i);
      l_sql := l_sql || '%type;' || chr(10);
    end loop;
    --
    l_sql := l_sql || '  begin' || chr(10);
    --
    for i in 1 .. p_columns.count
    loop
      l_var := variable_from_column(p_columns(i), 'l_');
      l_sql := l_sql || '    ' || l_var || ' := nvl(';
      l_var := variable_from_column(p_columns(i), 'p_');
      l_sql := l_sql || l_var || ', ';
      l_var := variable_from_column(p_pk_column, 'p_');
      l_sql := l_sql || p_columns(i) || '(' || l_var || '));' || chr(10);
    end loop;

    l_sql := l_sql || chr(10);
    --
    l_sql := l_sql || '    update  ' || lower(p_table_name) || chr(10);

    for i in 1 .. p_columns.count
    loop
      if i = 1 then
        l_sql := l_sql || '    set     ';
      else
        l_sql := l_sql || '            ';
      end if;

      l_var := variable_from_column(p_columns(i), 'l_');
      l_sql := l_sql || p_columns(i) || ' = ' || l_var;

      if i < p_columns.count then
        l_sql := l_sql || ',';
      end if;

      l_sql := l_sql || chr(10);
    end loop;

    l_var := variable_from_column(p_pk_column, 'p_');
    l_sql := l_sql || '    where   ' || lower(p_pk_column) || ' = ';
    l_sql := l_sql || l_var || ';' || chr(10);
    l_sql := l_sql || '  exception' || chr(10);
    l_sql := l_sql || '    when others then' || chr(10);
    l_sql := l_sql || '      p_error.fix;' || chr(10);
    l_sql := l_sql || '  end';
    --
    return l_sql;
  end;

  /**
   * Construct table delete procedure body
   *
   * @param p_table_name table name
   * @param p_pk_column PK column name
   *
   * @return table delete procedure body
   */
  function make_delete_body
  (
    p_table_name  in varchar2,
    p_pk_column   in varchar2
  )
  return varchar2
  as
    l_sql varchar2(32767) := '';
    l_var varchar2(30);
  begin
    l_sql := l_sql || make_delete_spec(
      p_table_name,
      p_pk_column
    );
    l_sql := l_sql || chr(10);
    --
    l_sql := l_sql || '  as' || chr(10);
    l_sql := l_sql || '  begin' || chr(10);
    l_sql := l_sql || '    delete from ' || lower(p_table_name) || chr(10);
    l_sql := l_sql || '    where       ' || lower(p_pk_column);
    l_var := variable_from_column(p_pk_column, 'p_');
    l_sql := l_sql || ' = ' || l_var || ';' || chr(10);
    l_sql := l_sql || '  exception' || chr(10);
    l_sql := l_sql || '    when others then' || chr(10);
    l_sql := l_sql || '      p_error.fix;' || chr(10);
    l_sql := l_sql || '  end';
    --
    return l_sql;
  end;

  /**
   * Construct table column getter body
   *
   * @param p_table_name table name
   * @param p_pk_column PK column name
   * @param p_column target table column
   *
   * @return table column getter body
   */
  function make_getter_body
  (
    p_table_name  in varchar2,
    p_pk_column   in varchar2,
    p_column      in varchar2
  )
  return varchar2
  as
    l_sql varchar2(32767) := '';
    l_var varchar2(30);
  begin
    l_sql := l_sql || make_getter_spec(
      p_table_name,
      p_pk_column,
      p_column
    );
    l_sql := l_sql || chr(10);
    --
    l_sql := l_sql || '  as' || chr(10);
    l_var := variable_from_column(p_column, 'l_');
    l_sql := l_sql || '    ' || l_var || ' ' || lower(p_table_name);
    l_sql := l_sql || '.' || lower(p_column) || '%type;' || chr(10);
    --
    l_sql := l_sql || '  begin' || chr(10);
    l_sql := l_sql || '    select  ' || lower(p_column) || chr(10);
    l_sql := l_sql || '    into    ' || l_var || chr(10);
    l_sql := l_sql || '    from    ' || lower(p_table_name) || chr(10);
    l_var := variable_from_column(p_pk_column, 'p_');
    l_sql := l_sql || '    where   ' || lower(p_pk_column) || ' = ';
    l_sql := l_sql || l_var || ';' || chr(10) || chr(10);
    l_var := variable_from_column(p_column, 'l_');
    l_sql := l_sql || '    return ' || l_var || ';' || chr(10);
    l_sql := l_sql || '  exception' || chr(10);
    l_sql := l_sql || '    when no_data_found then' || chr(10);
    l_sql := l_sql || '      return null;' || chr(10);
    l_sql := l_sql || '  end';
    --
    return l_sql;
  end;

  /**
   * Construct table column setter body
   *
   * @param p_table_name table name
   * @param p_pk_column PK column name
   * @param p_column target table column
   *
   * @return table column setter body
   */
  function make_setter_body
  (
    p_table_name  in varchar2,
    p_pk_column   in varchar2,
    p_column      in varchar2
  )
  return varchar2
  as
    l_sql varchar2(32767) := '';
    l_var varchar2(30);
  begin
    l_sql := l_sql || make_setter_spec(
      p_table_name,
      p_pk_column,
      p_column
    );
    l_sql := l_sql || chr(10);
    --
    l_sql := l_sql || '  as' || chr(10);
    l_sql := l_sql || '  begin' || chr(10);
    l_sql := l_sql || '    update  ' || lower(p_table_name) || chr(10);
    l_sql := l_sql || '    set     ' || lower(p_column) || ' = ';
    l_var := variable_from_column(p_column, 'p_');
    l_sql := l_sql || l_var || chr(10);
    l_var := variable_from_column(p_pk_column, 'p_');
    l_sql := l_sql || '    where   ' || lower(p_pk_column) || ' = ';
    l_sql := l_sql || l_var || ';' || chr(10);
    l_sql := l_sql || '  exception' || chr(10);
    l_sql := l_sql || '    when others then' || chr(10);
    l_sql := l_sql || '      p_error.fix;' || chr(10);
    l_sql := l_sql || '  end';
    --
    return l_sql;
  end;

  /**
   * Construct TAPI package body
   *
   * @param p_schema_name table schema name
   * @param p_table_name target table name
   *
   * @return package body
   */
  function make_tapi_body
  (
    p_schema_name in varchar2,
    p_table_name  in varchar2
  )
  return varchar2
  as
    l_body            varchar2(32767);
    l_name            varchar2(30)    := get_tapi_name(p_table_name);
    l_pk_column       varchar2(30);
    l_non_pk_columns  strings;
  begin
    l_body := 'create or replace' || chr(10);
    l_body := l_body || 'package body ' || lower(p_schema_name);
    l_body := l_body || '.' || l_name || chr(10);
    l_body := l_body || 'as' || chr(10) || chr(10);
    --
    l_pk_column := get_pk_column(p_schema_name, p_table_name);
    l_non_pk_columns := get_not_pk_columns(p_schema_name, p_table_name);
    --
    for i in 1 .. l_non_pk_columns.count
    loop
      l_body := l_body || make_getter_body(
        p_table_name,
        l_pk_column,
        l_non_pk_columns(i)
      );
      l_body := l_body || ';' || chr(10) || chr(10);
      l_body := l_body || make_setter_body(
        p_table_name,
        l_pk_column,
        l_non_pk_columns(i)
      );
      l_body := l_body || ';' || chr(10) || chr(10);
    end loop;
    --
    l_body := l_body || make_insert_body(
      p_table_name,
      l_pk_column,
      l_non_pk_columns
    );
    l_body := l_body || ';' || chr(10) || chr(10);
    l_body := l_body || make_update_body(
      p_table_name,
      l_pk_column,
      l_non_pk_columns
    );
    l_body := l_body || ';' || chr(10) || chr(10);
    l_body := l_body || make_delete_body(
      p_table_name,
      l_pk_column
    );
    l_body := l_body || ';' || chr(10) || chr(10);
    --
    l_body := l_body || 'end ' || l_name || ';' || chr(10);
    --
    return l_body;
  end;

  /**
   * Compile package
   *
   * @param p_spec package spec
   * @param p_body package body
   */
  procedure compile_package
  (
    p_spec  in varchar2,
    p_body  in varchar2
  )
  as
  begin
    execute immediate p_spec;
    execute immediate p_body;
  end;

  /**
   * Generate and compile TAPI package
   *
   * @param p_schema_name table schema name
   * @param p_table_name target table name
   */
  procedure generate_tapi
  (
    p_schema_name in varchar2 default user,
    p_table_name  in varchar2
  )
  as
    l_spec  varchar2(32767);
    l_body  varchar2(32767);
  begin
    l_spec := make_tapi_spec(p_schema_name, p_table_name);
    l_body := make_tapi_body(p_schema_name, p_table_name);
    --
    compile_package(l_spec, l_body);
  end;

  /**
   * Save some source to file
   *
   * @param p_name file name
   * @param p_data some data
   * @param p_type data type
   */
  procedure write_to_file
  (
    p_name  in varchar2,
    p_data  in varchar2,
    p_type  in varchar2
  )
  as
    l_ext   varchar2(3);
    --
    l_file  utl_file.file_type;
  begin
    l_ext :=
      case p_type
        when 'spec' then 'pks'
        when 'body' then 'pkb'
      end;
    --
    l_file := utl_file.fopen('SOURCE', lower(p_name) || '.' || l_ext, 'w');
    utl_file.put(l_file, p_data);
    utl_file.fclose(l_file);
  end;

  /**
   * Generate TAPI package and dump its source to SOURCE directory
   *
   * @param p_schema_name table schema name
   * @param p_table_name target table name
   */
  procedure dump_tapi
  (
    p_schema_name in varchar2 default user,
    p_table_name  in varchar2
  )
  as
    l_name  varchar2(30)    := get_tapi_name(p_table_name);
    l_spec  varchar2(32767);
    l_body  varchar2(32767);
  begin
    l_spec := make_tapi_spec(p_schema_name, p_table_name) || '/' || chr(10);
    write_to_file(l_name, l_spec, 'spec');
    l_body := make_tapi_body(p_schema_name, p_table_name) || '/' || chr(10);
    write_to_file(l_name, l_body, 'body');
  end;

end dev_utl;
/
