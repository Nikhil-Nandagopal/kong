local helpers = require "spec.helpers"
local migration = require "kong.db.migrations.core.007_140_to_150"


describe("#db migration core/007_140_to_150 spec", function()
  local _, db
  after_each(function()
    assert(db:reset())
  end)

  it("#postgres", function()
    _, db = helpers.get_db_utils("postgres", nil, nil,
                                 "kong.db.migrations.core",
                                 "007_140_to_150")
    local cn = db.connector
    assert(cn:connect_migrations())

    local res = assert(cn:query([[
      SELECT *
      FROM information_schema.columns
      WHERE table_schema = 'public'
      AND table_name     = 'routes'
      AND column_name    = 'path_handling';
    ]]))
    assert.same({}, res)

    assert(cn:run_up_migration("", migration.postgres.up))

    res = assert(cn:query([[
      SELECT *
      FROM information_schema.columns
      WHERE table_schema = 'public'
      AND table_name     = 'routes'
      AND column_name    = 'path_handling';
    ]]))
    assert.equals("routes", res[1].table_name)
    assert.equals("path_handling", res[1].column_name)
  end)

  it("#cassandra", function()
    _, db = helpers.get_db_utils("cassandra", nil, nil,
                                 "kong.db.migrations.core",
                                 "007_140_to_150")
    local cn = db.connector
    --assert(cn:connect_migrations())

    local rows = assert(cn:query([[
      INSERT INTO
      routes (id, created_at, updated_at, name, service_id, paths)
      VALUES(uuid(), now(), null, "test", null, {"/"});
    ]], nil, nil, "write"))
    assert.same({}, rows)
  end)
end)
