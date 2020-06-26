local helpers = require "spec.helpers"
local fmt = string.format


local function run_migration(db, subsystem, namespace, mig_name, options)
  local res = assert(db:run_migrations(
    {
      {
        subsystem = subsystem,
        namespace = namespace,
        migrations = {
          { name = mig_name }
        }
      }
    }, options))
  return res
end


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

    -- kong migrations up
    run_migration(db, "core", "kong.db.migrations.core", "007_140_to_150", {
      run_up = true,
    })

    res = assert(cn:query([[
      SELECT *
      FROM information_schema.columns
      WHERE table_schema = 'public'
      AND table_name     = 'routes'
      AND column_name    = 'path_handling';
    ]]))
    assert.equals(1, #res)
    assert.equals("routes", res[1].table_name)
    assert.equals("path_handling", res[1].column_name)
    -- migration has no `teardown` in postgres, no further tests needed
  end)

  it("#cassandra", function()
    local uuid = "c37d661d-7e61-49ea-96a5-68c34e83db3a"
    _, db = helpers.get_db_utils("cassandra", nil, nil,
                                 "kong.db.migrations.core",
                                 "007_140_to_150")
    local cn = db.connector

    -- BEFORE
    assert(cn:query(fmt([[
      INSERT INTO
      routes (partition, id, name, paths)
      VALUES('routes', %s, 'test', ['/']);
    ]], uuid)))

    local res = assert(cn:query(fmt([[
      SELECT * FROM routes WHERE partition = 'routes' AND id = %s;
    ]], uuid)))
    assert.same(1, #res)
    assert.same(uuid, res[1].id)
    assert.is_nil(res[1].path_handling)

    -- kong migrations up
    run_migration(db, "core", "kong.db.migrations.core", "007_140_to_150", {
      run_up = true,
    })

    -- MIGRATING
    res = assert(cn:query(fmt([[
      SELECT * FROM routes WHERE partition = 'routes' AND id = %s;
    ]], uuid)))
    assert.same(1, #res)
    assert.same(uuid, res[1].id)
    assert.is_nil(res[1].path_handling)

    -- kong migrations finish
    run_migration(db, "core", "kong.db.migrations.core", "007_140_to_150", {
      run_teardown = true,
    })

    -- AFTER
    res = assert(cn:query(fmt([[
      SELECT * FROM routes WHERE partition = 'routes' AND id = %s;
    ]], uuid)))
    assert.same(1, #res)
    assert.same(uuid, res[1].id)
    assert.same("v1", res[1].path_handling)
  end)
end)
