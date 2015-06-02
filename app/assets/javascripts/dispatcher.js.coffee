$ ->
  new Dispatcher()

class Dispatcher
  constructor: () ->
    @initSearch()
    @initPageScripts()

  initPageScripts: ->
    page = $('body').attr('data-page')

    unless page
      return false

    path = page.split(':')
    shortcut_handler = null

    switch page
      when 'projects:issues:index'
        Issues.init()
        shortcut_handler = new ShortcutsNavigation()
      when 'projects:issues:show'
        new Issue()
        shortcut_handler = new ShortcutsIssuable()
        new ZenMode()
      when 'projects:milestones:show'
        new Milestone()
      when 'projects:milestones:new', 'projects:milestones:edit'
        new ZenMode()
        new DropzoneInput($('.milestone-form'))
      when 'projects:compare:show'
        new Diff()
      when 'projects:issues:new','projects:issues:edit'
        GitLab.GfmAutoComplete.setup()
        shortcut_handler = new ShortcutsNavigation()
        new ZenMode()
        new DropzoneInput($('.issue-form'))
        if page == 'projects:issues:new'
          new IssuableForm($('.issue-form'))
      when 'projects:merge_requests:new', 'projects:merge_requests:edit'
        GitLab.GfmAutoComplete.setup()
        new Diff()
        shortcut_handler = new ShortcutsNavigation()
        new ZenMode()
        new DropzoneInput($('.merge-request-form'))
        if page == 'projects:merge_requests:new'
          new IssuableForm($('.merge-request-form'))
      when 'projects:merge_requests:show'
        new Diff()
        shortcut_handler = new ShortcutsIssuable()
        new ZenMode()
      when "projects:merge_requests:diffs"
        new Diff()
        new ZenMode()
      when 'projects:merge_requests:index'
        shortcut_handler = new ShortcutsNavigation()
        MergeRequests.init()
      when 'dashboard:show'
        new Dashboard()
        new Activities()
      when 'dashboard:projects:starred'
        new Activities()
        new ProjectsList()
      when 'projects:commit:show'
        new Commit()
        new Diff()
        new ZenMode()
        shortcut_handler = new ShortcutsNavigation()
      when 'projects:commits:show'
        shortcut_handler = new ShortcutsNavigation()
      when 'projects:show'
        new Activities()
        shortcut_handler = new ShortcutsNavigation()
      when 'groups:show'
        new Activities()
        shortcut_handler = new ShortcutsNavigation()
        new ProjectsList()
      when 'groups:group_members:index'
        new GroupMembers()
        new UsersSelect()
      when 'projects:project_members:index'
        new ProjectMembers()
        new UsersSelect()
      when 'groups:new', 'groups:edit', 'admin:groups:edit'
        new GroupAvatar()
      when 'projects:tree:show'
        new TreeView()
        shortcut_handler = new ShortcutsNavigation()
      when 'projects:blob:show'
        new BlobView()
        shortcut_handler = new ShortcutsNavigation()
      when 'projects:labels:new', 'projects:labels:edit'
        new Labels()
      when 'projects:network:show'
        # Ensure we don't create a particular shortcut handler here. This is
        # already created, where the network graph is created.
        shortcut_handler = true
      when 'projects:forks:new'
        new ProjectFork()
      when 'users:show'
        new User()
        new Activities()
      when 'admin:users:show'
        new ProjectsList()

    switch path.first()
      when 'admin'
        new Admin()
        switch path[1]
          when 'groups'
            new UsersSelect()
          when 'projects'
            new NamespaceSelect()
      when 'dashboard'
        shortcut_handler = new ShortcutsDashboardNavigation()
        switch path[1]
          when 'issues', 'merge_requests'
            new UsersSelect()
      when 'groups'
        switch path[1]
          when 'issues', 'merge_requests'
            new UsersSelect()
      when 'profiles'
        new Profile()
      when 'projects'
        new Project()
        new ProjectAvatar()
        switch path[1]
          when 'compare'
            shortcut_handler = new ShortcutsNavigation()
          when 'edit'
            shortcut_handler = new ShortcutsNavigation()
            new ProjectNew()
          when 'new'
            new ProjectNew()
          when 'show'
            new ProjectShow()
          when 'issues', 'merge_requests'
            new UsersSelect()
          when 'wikis'
            new Wikis()
            shortcut_handler = new ShortcutsNavigation()
            new ZenMode()
            new DropzoneInput($('.wiki-form'))
          when 'snippets', 'labels', 'graphs'
            shortcut_handler = new ShortcutsNavigation()
          when 'project_members', 'deploy_keys', 'hooks', 'services', 'protected_branches'
            shortcut_handler = new ShortcutsNavigation()


    # If we haven't installed a custom shortcut handler, install the default one
    if not shortcut_handler
      new Shortcuts()

  initSearch: ->
    opts = $('.search-autocomplete-opts')
    path = opts.data('autocomplete-path')
    project_id = opts.data('autocomplete-project-id')
    project_ref = opts.data('autocomplete-project-ref')

    new SearchAutocomplete(path, project_id, project_ref)
