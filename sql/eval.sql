create or replace function eval(text) returns SETOF record as $foop$
declare 
res record;
begin
    begin
    for res in execute $1 loop
        return next res;
    end loop;
    exception
	when invalid_cursor_definition THEN
	     execute $1;
    END;     
end;
$foop$ language plpgsql;

create or replace function derp() returns VOID as $foop$
DECLARE
row record;
begin
	FOR row IN SELECT * FROM pg_proc INNER JOIN pg_namespace ns ON (pg_proc.pronamespace = ns.oid)
	WHERE ns.nspname = 'public'  order by proname LOOP
	EXECUTE 'DROP FUNCTION ' || row.nspname || '.' || row.proname || '(' || oidvectortypes(row.proargtypes) || ')';
       END LOOP;
END;
$foop$ language 'plpgsql';