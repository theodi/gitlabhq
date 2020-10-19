import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { createStore } from '~/serverless/store';
import missingPrometheusComponent from '~/serverless/components/missing_prometheus.vue';

describe('missingPrometheusComponent', () => {
  let wrapper;

  const createComponent = missingData => {
    const store = createStore({ clustersPath: '/clusters', helpPath: '/help' });

    wrapper = shallowMount(missingPrometheusComponent, { store, propsData: { missingData } });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  it('should render missing prometheus message', () => {
    createComponent(false);
    const { vm } = wrapper;

    expect(vm.$el.querySelector('.state-description').innerHTML.trim()).toContain(
      'Function invocation metrics require Prometheus to be installed first.',
    );

    expect(wrapper.find(GlButton).attributes('variant')).toBe('success');
  });

  it('should render no prometheus data message', () => {
    createComponent(true);
    const { vm } = wrapper;

    expect(vm.$el.querySelector('.state-description').innerHTML.trim()).toContain(
      'Invocation metrics loading or not available at this time.',
    );
  });
});
