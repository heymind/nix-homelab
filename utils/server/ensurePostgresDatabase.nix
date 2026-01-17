{name}: {
  enable = true;
  ensureDatabases = [name];
  ensureUsers = [
    {
      name = name;
      ensureClauses.login = true;
      ensureDBOwnership = true;
    }
  ];
}

