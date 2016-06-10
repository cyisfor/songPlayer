CREATE OR REPLACE FUNCTION testExecute (sql_select TEXT, parm hstore)
    RETURNS record
    LANGUAGE plpgsql
AS $$
DECLARE
res record;
inparm record;
BEGIN
        inparm := ROW();
        PERFORM populate_record(inparm,parm);
        EXECUTE sql_select INTO res USING inparm;
        RETURN res;
END;
$$;
