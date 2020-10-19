. scripts/utils.sh

export SETUP_DB=${SETUP_DB:-true}
export USE_BUNDLE_INSTALL=${USE_BUNDLE_INSTALL:-true}
export BUNDLE_INSTALL_FLAGS=${BUNDLE_INSTALL_FLAGS:-"--without=production development --jobs=$(nproc) --path=vendor --retry=3 --quiet"}

if [ "$USE_BUNDLE_INSTALL" != "false" ]; then
  bundle --version
  run_timed_command "bundle install --clean ${BUNDLE_INSTALL_FLAGS}"
  run_timed_command "bundle check"
  # When we test multiple versions of PG in the same pipeline, we have a single `setup-test-env`
  # job but the `pg` gem needs to be rebuilt since it includes extensions (https://guides.rubygems.org/gems-with-extensions).
  # Uncomment the following line if multiple versions of PG are tested in the same pipeline.
  run_timed_command "bundle pristine pg"
fi

cp config/gitlab.yml.example config/gitlab.yml
sed -i 's/bin_path: \/usr\/bin\/git/bin_path: \/usr\/local\/bin\/git/' config/gitlab.yml

cp config/database.yml.postgresql config/database.yml

if [ -f config/database_geo.yml.postgresql ]; then
  cp config/database_geo.yml.postgresql config/database_geo.yml
fi

# Set user to a non-superuser to ensure we test permissions
sed -i 's/username: root/username: gitlab/g' config/database.yml

sed -i 's/localhost/postgres/g' config/database.yml
sed -i 's/username: git/username: postgres/g' config/database.yml

if [ -f config/database_geo.yml ]; then
  sed -i 's/localhost/postgres/g' config/database_geo.yml
  sed -i 's/username: git/username: postgres/g' config/database_geo.yml
fi

cp config/cable.yml.example config/cable.yml
sed -i 's|url:.*$|url: redis://redis:6379|g' config/cable.yml

cp config/resque.yml.example config/resque.yml
sed -i 's|url:.*$|url: redis://redis:6379|g' config/resque.yml

cp config/redis.cache.yml.example config/redis.cache.yml
sed -i 's|url:.*$|url: redis://redis:6379/10|g' config/redis.cache.yml

cp config/redis.queues.yml.example config/redis.queues.yml
sed -i 's|url:.*$|url: redis://redis:6379/11|g' config/redis.queues.yml

cp config/redis.shared_state.yml.example config/redis.shared_state.yml
sed -i 's|url:.*$|url: redis://redis:6379/12|g' config/redis.shared_state.yml

if [ "$SETUP_DB" != "false" ]; then
  setup_db
elif getent hosts postgres; then
  setup_db_user_only
fi
