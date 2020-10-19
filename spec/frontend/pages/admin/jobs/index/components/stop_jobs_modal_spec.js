import Vue from 'vue';
import mountComponent from 'helpers/vue_mount_component_helper';
import { TEST_HOST } from 'jest/helpers/test_constants';
import { redirectTo } from '~/lib/utils/url_utility';
import axios from '~/lib/utils/axios_utils';
import stopJobsModal from '~/pages/admin/jobs/index/components/stop_jobs_modal.vue';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  redirectTo: jest.fn(),
}));

describe('stop_jobs_modal.vue', () => {
  const props = {
    url: `${TEST_HOST}/stop_jobs_modal.vue/stopAll`,
  };
  let vm;

  afterEach(() => {
    vm.$destroy();
  });

  beforeEach(() => {
    const Component = Vue.extend(stopJobsModal);
    vm = mountComponent(Component, props);
  });

  describe('onSubmit', () => {
    it('stops jobs and redirects to overview page', done => {
      const responseURL = `${TEST_HOST}/stop_jobs_modal.vue/jobs`;
      jest.spyOn(axios, 'post').mockImplementation(url => {
        expect(url).toBe(props.url);
        return Promise.resolve({
          request: {
            responseURL,
          },
        });
      });

      vm.onSubmit()
        .then(() => {
          expect(redirectTo).toHaveBeenCalledWith(responseURL);
        })
        .then(done)
        .catch(done.fail);
    });

    it('displays error if stopping jobs failed', done => {
      const dummyError = new Error('stopping jobs failed');
      jest.spyOn(axios, 'post').mockImplementation(url => {
        expect(url).toBe(props.url);
        return Promise.reject(dummyError);
      });

      vm.onSubmit()
        .then(done.fail)
        .catch(error => {
          expect(error).toBe(dummyError);
          expect(redirectTo).not.toHaveBeenCalled();
        })
        .then(done)
        .catch(done.fail);
    });
  });
});
