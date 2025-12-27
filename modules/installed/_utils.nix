{
  ensurePostgresDatabase = {name}: {
    ensureDatabases = [name];
    ensureUsers = [
      {
        name = name;
        ensureClauses.login = true;
        ensureDBOwnership = true;
      }
    ];
  };
}
