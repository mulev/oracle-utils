create or replace
package dev_utl
as

  /**
   * This package provides some APIs for developer needs
   *
   * @author Mike Mulev (mailto:m.mulev@gmail.com)
   */

  --

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
  );

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
  );

end dev_utl;
/
