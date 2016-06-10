create table pids (
       id INTEGER PRIMARY KEY,
       pid INTEGER);

drop function setPID(_who integer,_pid integer);
create function setPID(_who integer,_pid integer) RETURNS void AS $$
BEGIN
   INSERT INTO pids (id,pid) VALUES (_who,_pid);
EXCEPTION
   WHEN unique_violation THEN
        UPDATE pids SET pid = _pid WHERE id = _who;
END;
$$ language plpgsql;