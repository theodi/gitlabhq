import Vuex from 'vuex';
import { createLocalVue, shallowMount } from '@vue/test-utils';
import { GlLink } from '@gitlab/ui';
import IdeStatusList from '~/ide/components/ide_status_list.vue';
import TerminalSyncStatusSafe from '~/ide/components/terminal_sync/terminal_sync_status_safe.vue';

const TEST_FILE = {
  name: 'lorem.md',
  editorRow: 3,
  editorColumn: 23,
  fileLanguage: 'markdown',
  content: 'abc\nndef',
  permalink: '/lorem.md',
};

const localVue = createLocalVue();
localVue.use(Vuex);

describe('ide/components/ide_status_list', () => {
  let activeFile;
  let store;
  let wrapper;

  const findLink = () => wrapper.find(GlLink);
  const createComponent = (options = {}) => {
    store = new Vuex.Store({
      getters: {
        activeFile: () => activeFile,
      },
    });

    wrapper = shallowMount(IdeStatusList, {
      localVue,
      store,
      ...options,
    });
  };

  beforeEach(() => {
    activeFile = TEST_FILE;
  });

  afterEach(() => {
    wrapper.destroy();

    store = null;
    wrapper = null;
  });

  const getEditorPosition = file => `${file.editorRow}:${file.editorColumn}`;

  describe('with regular file', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows a link to the file that contains the file name', () => {
      expect(findLink().attributes('href')).toBe(TEST_FILE.permalink);
      expect(findLink().text()).toBe(TEST_FILE.name);
    });

    it('shows file eol', () => {
      expect(wrapper.text()).not.toContain('CRLF');
      expect(wrapper.text()).toContain('LF');
    });

    it('shows file editor position', () => {
      expect(wrapper.text()).toContain(getEditorPosition(TEST_FILE));
    });

    it('shows file language', () => {
      expect(wrapper.text()).toContain(TEST_FILE.fileLanguage);
    });
  });

  describe('with binary file', () => {
    beforeEach(() => {
      activeFile.name = 'abc.dat';
      activeFile.content = '🐱'; // non-ascii binary content
      createComponent();
    });

    it('does not show file editor position', () => {
      expect(wrapper.text()).not.toContain(getEditorPosition(TEST_FILE));
    });
  });

  it('renders terminal sync status', () => {
    createComponent();

    expect(wrapper.find(TerminalSyncStatusSafe).exists()).toBe(true);
  });
});
