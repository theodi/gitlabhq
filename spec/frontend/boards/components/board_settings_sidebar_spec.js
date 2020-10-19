import '~/boards/models/list';
import MockAdapter from 'axios-mock-adapter';
import axios from 'axios';
import Vuex from 'vuex';
import { shallowMount, createLocalVue } from '@vue/test-utils';
import { GlDrawer, GlLabel } from '@gitlab/ui';
import BoardSettingsSidebar from '~/boards/components/board_settings_sidebar.vue';
import boardsStore from '~/boards/stores/boards_store';
import { createStore } from '~/boards/stores';
import sidebarEventHub from '~/sidebar/event_hub';
import { inactiveId, LIST } from '~/boards/constants';

const localVue = createLocalVue();

localVue.use(Vuex);

describe('BoardSettingsSidebar', () => {
  let wrapper;
  let mock;
  let store;
  const labelTitle = 'test';
  const labelColor = '#FFFF';
  const listId = 1;

  const createComponent = () => {
    wrapper = shallowMount(BoardSettingsSidebar, {
      store,
      localVue,
    });
  };
  const findLabel = () => wrapper.find(GlLabel);
  const findDrawer = () => wrapper.find(GlDrawer);

  beforeEach(() => {
    store = createStore();
    store.state.activeId = inactiveId;
    store.state.sidebarType = LIST;
    boardsStore.create();
  });

  afterEach(() => {
    jest.restoreAllMocks();
    wrapper.destroy();
  });

  describe('when sidebarType is "list"', () => {
    it('finds a GlDrawer component', () => {
      createComponent();

      expect(findDrawer().exists()).toBe(true);
    });

    describe('on close', () => {
      it('closes the sidebar', async () => {
        createComponent();

        findDrawer().vm.$emit('close');

        await wrapper.vm.$nextTick();

        expect(wrapper.find(GlDrawer).exists()).toBe(false);
      });

      it('closes the sidebar when emitting the correct event', async () => {
        createComponent();

        sidebarEventHub.$emit('sidebar.closeAll');

        await wrapper.vm.$nextTick();

        expect(wrapper.find(GlDrawer).exists()).toBe(false);
      });
    });

    describe('when activeId is zero', () => {
      it('renders GlDrawer with open false', () => {
        createComponent();

        expect(findDrawer().props('open')).toBe(false);
      });
    });

    describe('when activeId is greater than zero', () => {
      beforeEach(() => {
        mock = new MockAdapter(axios);

        boardsStore.addList({
          id: listId,
          label: { title: labelTitle, color: labelColor },
          list_type: 'label',
        });
        store.state.activeId = 1;
        store.state.sidebarType = LIST;
      });

      afterEach(() => {
        boardsStore.removeList(listId);
      });

      it('renders GlDrawer with open false', () => {
        createComponent();

        expect(findDrawer().props('open')).toBe(true);
      });
    });

    describe('when activeId is in boardsStore', () => {
      beforeEach(() => {
        mock = new MockAdapter(axios);

        boardsStore.addList({
          id: listId,
          label: { title: labelTitle, color: labelColor },
          list_type: 'label',
        });

        store.state.activeId = listId;
        store.state.sidebarType = LIST;

        createComponent();
      });

      afterEach(() => {
        mock.restore();
      });

      it('renders label title', () => {
        expect(findLabel().props('title')).toBe(labelTitle);
      });

      it('renders label background color', () => {
        expect(findLabel().props('backgroundColor')).toBe(labelColor);
      });
    });

    describe('when activeId is not in boardsStore', () => {
      beforeEach(() => {
        mock = new MockAdapter(axios);

        boardsStore.addList({ id: listId, label: { title: labelTitle, color: labelColor } });

        store.state.activeId = inactiveId;

        createComponent();
      });

      afterEach(() => {
        mock.restore();
      });

      it('does not render GlLabel', () => {
        expect(findLabel().exists()).toBe(false);
      });
    });
  });

  describe('when sidebarType is not List', () => {
    beforeEach(() => {
      store.state.sidebarType = '';
      createComponent();
    });

    it('does not render GlDrawer', () => {
      expect(findDrawer().exists()).toBe(false);
    });
  });
});
