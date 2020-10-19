import { createLocalVue, shallowMount } from '@vue/test-utils';
import SquashBeforeMerge from '~/vue_merge_request_widget/components/states/squash_before_merge.vue';
import { SQUASH_BEFORE_MERGE } from '~/vue_merge_request_widget/i18n';

const localVue = createLocalVue();

describe('Squash before merge component', () => {
  let wrapper;

  const createComponent = props => {
    wrapper = shallowMount(localVue.extend(SquashBeforeMerge), {
      localVue,
      propsData: {
        ...props,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  const findLabel = () => wrapper.find('[data-testid="squashLabel"]');

  describe('checkbox', () => {
    const findCheckbox = () => wrapper.find('.js-squash-checkbox');

    it('is unchecked if passed value prop is false', () => {
      createComponent({
        value: false,
      });

      expect(findCheckbox().element.checked).toBeFalsy();
    });

    it('is checked if passed value prop is true', () => {
      createComponent({
        value: true,
      });

      expect(findCheckbox().element.checked).toBeTruthy();
    });

    it('changes value on click', done => {
      createComponent({
        value: false,
      });

      findCheckbox().element.checked = true;

      findCheckbox().trigger('change');

      wrapper.vm.$nextTick(() => {
        expect(findCheckbox().element.checked).toBeTruthy();
        done();
      });
    });

    it('is disabled if isDisabled prop is true', () => {
      createComponent({
        value: false,
        isDisabled: true,
      });

      expect(findCheckbox().attributes('disabled')).toBeTruthy();
    });
  });

  describe('label', () => {
    describe.each`
      isDisabled | expectation
      ${true}    | ${'grays out text if it is true'}
      ${false}   | ${'does not gray out text if it is false'}
    `('isDisabled prop', ({ isDisabled, expectation }) => {
      beforeEach(() => {
        createComponent({
          value: false,
          isDisabled,
        });
      });

      it(expectation, () => {
        expect(findLabel().classes('gl-text-gray-400')).toBe(isDisabled);
      });
    });
  });

  describe('tooltip', () => {
    const tooltipTitle = () => findLabel().attributes('title');

    it('does not render when isDisabled is false', () => {
      createComponent({
        value: true,
        isDisabled: false,
      });
      expect(tooltipTitle()).toBeUndefined();
    });

    it('display message when when isDisabled is true', () => {
      createComponent({
        value: true,
        isDisabled: true,
      });

      expect(tooltipTitle()).toBe(SQUASH_BEFORE_MERGE.tooltipTitle);
    });
  });

  describe('about link', () => {
    it('is not rendered if no help path is passed', () => {
      createComponent({
        value: false,
      });

      const aboutLink = wrapper.find('a');

      expect(aboutLink.exists()).toBeFalsy();
    });

    it('is rendered if  help path is passed', () => {
      createComponent({
        value: false,
        helpPath: 'test-path',
      });

      const aboutLink = wrapper.find('a');

      expect(aboutLink.exists()).toBeTruthy();
    });

    it('should have a correct help path if passed', () => {
      createComponent({
        value: false,
        helpPath: 'test-path',
      });

      const aboutLink = wrapper.find('a');

      expect(aboutLink.attributes('href')).toEqual('test-path');
    });
  });
});
