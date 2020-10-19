import Vuex from 'vuex';
import { mount, createLocalVue } from '@vue/test-utils';
import { GlEmptyState, GlModal } from '@gitlab/ui';
import stubChildren from 'helpers/stub_children';
import Tracking from '~/tracking';
import * as getters from '~/packages/details/store/getters';
import PackagesApp from '~/packages/details/components/app.vue';
import PackageTitle from '~/packages/details/components/package_title.vue';

import * as SharedUtils from '~/packages/shared/utils';
import { TrackingActions } from '~/packages/shared/constants';
import PackagesListLoader from '~/packages/shared/components/packages_list_loader.vue';
import PackageListRow from '~/packages/shared/components/package_list_row.vue';

import DependencyRow from '~/packages/details/components/dependency_row.vue';
import PackageHistory from '~/packages/details/components/package_history.vue';
import AdditionalMetadata from '~/packages/details/components/additional_metadata.vue';
import InstallationCommands from '~/packages/details/components/installation_commands.vue';

import {
  composerPackage,
  conanPackage,
  mavenPackage,
  mavenFiles,
  npmPackage,
  npmFiles,
  nugetPackage,
} from '../../mock_data';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('PackagesApp', () => {
  let wrapper;
  let store;
  const fetchPackageVersions = jest.fn();
  const deletePackage = jest.fn();
  const defaultProjectName = 'bar';
  const { location } = window;

  function createComponent({
    packageEntity = mavenPackage,
    packageFiles = mavenFiles,
    isLoading = false,
    projectName = defaultProjectName,
  } = {}) {
    store = new Vuex.Store({
      state: {
        isLoading,
        packageEntity,
        packageFiles,
        canDelete: true,
        emptySvgPath: 'empty-illustration',
        npmPath: 'foo',
        npmHelpPath: 'foo',
        projectName,
        projectListUrl: 'project_url',
        groupListUrl: 'group_url',
      },
      actions: {
        deletePackage,
        fetchPackageVersions,
      },
      getters,
    });

    wrapper = mount(PackagesApp, {
      localVue,
      store,
      stubs: {
        ...stubChildren(PackagesApp),
        PackageTitle: false,
        TitleArea: false,
        GlButton: false,
        GlModal: false,
        GlTab: false,
        GlTabs: false,
        GlTable: false,
      },
    });
  }

  const packageTitle = () => wrapper.find(PackageTitle);
  const emptyState = () => wrapper.find(GlEmptyState);
  const allFileRows = () => wrapper.findAll('.js-file-row');
  const firstFileDownloadLink = () => wrapper.find('.js-file-download');
  const deleteButton = () => wrapper.find('.js-delete-button');
  const deleteModal = () => wrapper.find(GlModal);
  const modalDeleteButton = () => wrapper.find({ ref: 'modal-delete-button' });
  const versionsTab = () => wrapper.find('.js-versions-tab > a');
  const packagesLoader = () => wrapper.find(PackagesListLoader);
  const packagesVersionRows = () => wrapper.findAll(PackageListRow);
  const noVersionsMessage = () => wrapper.find('[data-testid="no-versions-message"]');
  const dependenciesTab = () => wrapper.find('.js-dependencies-tab > a');
  const dependenciesCountBadge = () => wrapper.find('[data-testid="dependencies-badge"]');
  const noDependenciesMessage = () => wrapper.find('[data-testid="no-dependencies-message"]');
  const dependencyRows = () => wrapper.findAll(DependencyRow);
  const findPackageHistory = () => wrapper.find(PackageHistory);
  const findAdditionalMetadata = () => wrapper.find(AdditionalMetadata);
  const findInstallationCommands = () => wrapper.find(InstallationCommands);

  beforeEach(() => {
    delete window.location;
    window.location = { replace: jest.fn() };
  });

  afterEach(() => {
    wrapper.destroy();
    window.location = location;
  });

  it('renders the app and displays the package title', () => {
    createComponent();

    expect(packageTitle()).toExist();
  });

  it('renders an empty state component when no an invalid package is passed as a prop', () => {
    createComponent({
      packageEntity: {},
    });

    expect(emptyState()).toExist();
  });

  it('package history has the right props', () => {
    createComponent();
    expect(findPackageHistory().exists()).toBe(true);
    expect(findPackageHistory().props('packageEntity')).toEqual(wrapper.vm.packageEntity);
    expect(findPackageHistory().props('projectName')).toEqual(wrapper.vm.projectName);
  });

  it('additional metadata has the right props', () => {
    createComponent();
    expect(findAdditionalMetadata().exists()).toBe(true);
    expect(findAdditionalMetadata().props('packageEntity')).toEqual(wrapper.vm.packageEntity);
  });

  it('installation commands has the right props', () => {
    createComponent();
    expect(findInstallationCommands().exists()).toBe(true);
    expect(findInstallationCommands().props('packageEntity')).toEqual(wrapper.vm.packageEntity);
  });

  it('hides the files table if package type is COMPOSER', () => {
    createComponent({ packageEntity: composerPackage });
    expect(allFileRows().exists()).toBe(false);
  });

  it('renders a single file for an npm package as they only contain one file', () => {
    createComponent({ packageEntity: npmPackage, packageFiles: npmFiles });

    expect(allFileRows()).toExist();
    expect(allFileRows()).toHaveLength(1);
  });

  it('renders multiple files for a package that contains more than one file', () => {
    createComponent();

    expect(allFileRows()).toExist();
    expect(allFileRows()).toHaveLength(2);
  });

  it('allows the user to download a package file by rendering a download link', () => {
    createComponent();

    expect(allFileRows()).toExist();
    expect(firstFileDownloadLink().vm.$attrs.href).toContain('download');
  });

  describe('deleting packages', () => {
    beforeEach(() => {
      createComponent();
      deleteButton().trigger('click');
    });

    it('shows the delete confirmation modal when delete is clicked', () => {
      expect(deleteModal()).toExist();
    });
  });

  describe('versions', () => {
    describe('api call', () => {
      beforeEach(() => {
        createComponent();
      });

      it('makes api request on first click of tab', () => {
        versionsTab().trigger('click');

        expect(fetchPackageVersions).toHaveBeenCalled();
      });
    });

    it('displays the loader when state is loading', () => {
      createComponent({ isLoading: true });

      expect(packagesLoader().exists()).toBe(true);
    });

    it('displays the correct version count when the package has versions', () => {
      createComponent({ packageEntity: npmPackage });

      expect(packagesVersionRows()).toHaveLength(npmPackage.versions.length);
    });

    it('displays the no versions message when there are none', () => {
      createComponent();

      expect(noVersionsMessage().exists()).toBe(true);
    });
  });

  describe('dependency links', () => {
    it('does not show the dependency links for a non nuget package', () => {
      createComponent();

      expect(dependenciesTab().exists()).toBe(false);
    });

    it('shows the dependencies tab with 0 count when a nuget package with no dependencies', () => {
      createComponent({
        packageEntity: {
          ...nugetPackage,
          dependency_links: [],
        },
      });

      return wrapper.vm.$nextTick(() => {
        const dependenciesBadge = dependenciesCountBadge();

        expect(dependenciesTab().exists()).toBe(true);
        expect(dependenciesBadge.exists()).toBe(true);
        expect(dependenciesBadge.text()).toBe('0');
        expect(noDependenciesMessage().exists()).toBe(true);
      });
    });

    it('renders the correct number of dependency rows for a nuget package', () => {
      createComponent({ packageEntity: nugetPackage });

      return wrapper.vm.$nextTick(() => {
        const dependenciesBadge = dependenciesCountBadge();

        expect(dependenciesTab().exists()).toBe(true);
        expect(dependenciesBadge.exists()).toBe(true);
        expect(dependenciesBadge.text()).toBe(nugetPackage.dependency_links.length.toString());
        expect(dependencyRows()).toHaveLength(nugetPackage.dependency_links.length);
      });
    });
  });

  describe('tracking and delete', () => {
    const doDelete = async () => {
      deleteButton().trigger('click');
      await wrapper.vm.$nextTick();
      modalDeleteButton().trigger('click');
    };

    describe('delete', () => {
      const originalReferrer = document.referrer;
      const setReferrer = (value = defaultProjectName) => {
        Object.defineProperty(document, 'referrer', {
          value,
          configurable: true,
        });
      };

      afterEach(() => {
        Object.defineProperty(document, 'referrer', {
          value: originalReferrer,
          configurable: true,
        });
      });

      it('calls the proper vuex action', async () => {
        createComponent({ packageEntity: npmPackage });
        await doDelete();
        expect(deletePackage).toHaveBeenCalled();
      });

      it('when referrer contains project name calls window.replace with project url', async () => {
        setReferrer();
        deletePackage.mockResolvedValue();
        createComponent({ packageEntity: npmPackage });
        await doDelete();
        await deletePackage();
        expect(window.location.replace).toHaveBeenCalledWith(
          'project_url?showSuccessDeleteAlert=true',
        );
      });

      it('when referrer does not contain project name calls window.replace with group url', async () => {
        setReferrer('baz');
        deletePackage.mockResolvedValue();
        createComponent({ packageEntity: npmPackage });
        await doDelete();
        await deletePackage();
        expect(window.location.replace).toHaveBeenCalledWith(
          'group_url?showSuccessDeleteAlert=true',
        );
      });
    });

    describe('tracking', () => {
      let eventSpy;
      let utilSpy;
      const category = 'foo';

      beforeEach(() => {
        eventSpy = jest.spyOn(Tracking, 'event');
        utilSpy = jest.spyOn(SharedUtils, 'packageTypeToTrackCategory').mockReturnValue(category);
      });

      it('tracking category calls packageTypeToTrackCategory', () => {
        createComponent({ packageEntity: conanPackage });
        expect(wrapper.vm.tracking.category).toBe(category);
        expect(utilSpy).toHaveBeenCalledWith('conan');
      });

      it(`delete button on delete modal call event with ${TrackingActions.DELETE_PACKAGE}`, async () => {
        createComponent({ packageEntity: npmPackage });
        await doDelete();
        expect(eventSpy).toHaveBeenCalledWith(
          category,
          TrackingActions.DELETE_PACKAGE,
          expect.any(Object),
        );
      });

      it(`file download link call event with ${TrackingActions.PULL_PACKAGE}`, () => {
        createComponent({ packageEntity: conanPackage });

        firstFileDownloadLink().vm.$emit('click');
        expect(eventSpy).toHaveBeenCalledWith(
          category,
          TrackingActions.PULL_PACKAGE,
          expect.any(Object),
        );
      });
    });
  });
});
