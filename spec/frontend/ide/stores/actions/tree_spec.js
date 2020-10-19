import MockAdapter from 'axios-mock-adapter';
import testAction from 'helpers/vuex_action_helper';
import { TEST_HOST } from 'jest/helpers/test_constants';
import { showTreeEntry, getFiles, setDirectoryData } from '~/ide/stores/actions/tree';
import * as types from '~/ide/stores/mutation_types';
import axios from '~/lib/utils/axios_utils';
import { createStore } from '~/ide/stores';
import service from '~/ide/services';
import { createRouter } from '~/ide/ide_router';
import { file, createEntriesFromPaths } from '../../helpers';

describe('Multi-file store tree actions', () => {
  let projectTree;
  let mock;
  let store;
  let router;

  const basicCallParameters = {
    endpoint: 'rootEndpoint',
    projectId: 'abcproject',
    branch: 'master',
    branchId: 'master',
    ref: '12345678',
  };

  beforeEach(() => {
    store = createStore();
    router = createRouter(store);
    jest.spyOn(router, 'push').mockImplementation();

    mock = new MockAdapter(axios);

    store.state.currentProjectId = 'abcproject';
    store.state.currentBranchId = 'master';
    store.state.projects.abcproject = {
      web_url: '',
      path_with_namespace: 'foo/abcproject',
    };
  });

  afterEach(() => {
    mock.restore();
  });

  describe('getFiles', () => {
    describe('success', () => {
      beforeEach(() => {
        jest.spyOn(service, 'getFiles');

        mock
          .onGet(/(.*)/)
          .replyOnce(200, [
            'file.txt',
            'folder/fileinfolder.js',
            'folder/subfolder/fileinsubfolder.js',
          ]);
      });

      it('calls service getFiles', () => {
        return (
          store
            .dispatch('getFiles', basicCallParameters)
            // getFiles actions calls lodash.defer
            .then(() => jest.runOnlyPendingTimers())
            .then(() => {
              expect(service.getFiles).toHaveBeenCalledWith('foo/abcproject', '12345678');
            })
        );
      });

      it('adds data into tree', done => {
        store
          .dispatch('getFiles', basicCallParameters)
          .then(() => {
            // The populating of the tree is deferred for performance reasons.
            // See this merge request for details: https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/25700
            jest.advanceTimersByTime(1);
          })
          .then(() => {
            projectTree = store.state.trees['abcproject/master'];

            expect(projectTree.tree.length).toBe(2);
            expect(projectTree.tree[0].type).toBe('tree');
            expect(projectTree.tree[0].tree[1].name).toBe('fileinfolder.js');
            expect(projectTree.tree[1].type).toBe('blob');
            expect(projectTree.tree[0].tree[0].tree[0].type).toBe('blob');
            expect(projectTree.tree[0].tree[0].tree[0].name).toBe('fileinsubfolder.js');

            done();
          })
          .catch(done.fail);
      });
    });

    describe('error', () => {
      it('dispatches error action', done => {
        const dispatch = jest.fn();

        store.state.projects = {
          'abc/def': {
            web_url: `${TEST_HOST}/files`,
            branches: {
              'master-testing': {
                commit: {
                  id: '12345',
                },
              },
            },
          },
        };
        const getters = {
          findBranch: () => store.state.projects['abc/def'].branches['master-testing'],
        };

        mock.onGet(/(.*)/).replyOnce(500);

        getFiles(
          {
            commit() {},
            dispatch,
            state: store.state,
            getters,
          },
          {
            projectId: 'abc/def',
            branchId: 'master-testing',
          },
        )
          .then(done.fail)
          .catch(() => {
            expect(dispatch).toHaveBeenCalledWith('setErrorMessage', {
              text: 'An error occurred while loading all the files.',
              action: expect.any(Function),
              actionText: 'Please try again',
              actionPayload: { projectId: 'abc/def', branchId: 'master-testing' },
            });
            done();
          });
      });
    });
  });

  describe('toggleTreeOpen', () => {
    let tree;

    beforeEach(() => {
      tree = file('testing', '1', 'tree');
      store.state.entries[tree.path] = tree;
    });

    it('toggles the tree open', done => {
      store
        .dispatch('toggleTreeOpen', tree.path)
        .then(() => {
          expect(tree.opened).toBeTruthy();

          done();
        })
        .catch(done.fail);
    });
  });

  describe('showTreeEntry', () => {
    beforeEach(() => {
      const paths = [
        'grandparent',
        'ancestor',
        'grandparent/parent',
        'grandparent/aunt',
        'grandparent/parent/child.txt',
        'grandparent/aunt/cousing.txt',
      ];

      Object.assign(store.state.entries, createEntriesFromPaths(paths));
    });

    it('opens the parents', done => {
      testAction(
        showTreeEntry,
        'grandparent/parent/child.txt',
        store.state,
        [{ type: types.SET_TREE_OPEN, payload: 'grandparent/parent' }],
        [{ type: 'showTreeEntry', payload: 'grandparent/parent' }],
        done,
      );
    });
  });

  describe('setDirectoryData', () => {
    it('sets tree correctly if there are no opened files yet', done => {
      const treeFile = file({ name: 'README.md' });
      store.state.trees['abcproject/master'] = {};

      testAction(
        setDirectoryData,
        { projectId: 'abcproject', branchId: 'master', treeList: [treeFile] },
        store.state,
        [
          {
            type: types.SET_DIRECTORY_DATA,
            payload: {
              treePath: 'abcproject/master',
              data: [treeFile],
            },
          },
          {
            type: types.TOGGLE_LOADING,
            payload: {
              entry: {},
              forceValue: false,
            },
          },
        ],
        [],
        done,
      );
    });
  });
});
