import Vue from 'vue';
import mountComponent from 'helpers/vue_mount_component_helper';
import DeprecatedModal2 from '~/vue_shared/components/deprecated_modal_2.vue';

const modalComponent = Vue.extend(DeprecatedModal2);

describe('DeprecatedModal2', () => {
  let vm;

  afterEach(() => {
    vm.$destroy();
  });

  describe('props', () => {
    describe('with id', () => {
      const props = {
        id: 'my-modal',
      };

      beforeEach(() => {
        vm = mountComponent(modalComponent, props);
      });

      it('assigns the id to the modal', () => {
        expect(vm.$el.id).toBe(props.id);
      });
    });

    describe('without id', () => {
      beforeEach(() => {
        vm = mountComponent(modalComponent, {});
      });

      it('does not add an id attribute to the modal', () => {
        expect(vm.$el.hasAttribute('id')).toBe(false);
      });
    });

    describe('with headerTitleText', () => {
      const props = {
        headerTitleText: 'my title text',
      };

      beforeEach(() => {
        vm = mountComponent(modalComponent, props);
      });

      it('sets the modal title', () => {
        const modalTitle = vm.$el.querySelector('.modal-title');

        expect(modalTitle.innerHTML.trim()).toBe(props.headerTitleText);
      });
    });

    describe('with footerPrimaryButtonVariant', () => {
      const props = {
        footerPrimaryButtonVariant: 'danger',
      };

      beforeEach(() => {
        vm = mountComponent(modalComponent, props);
      });

      it('sets the primary button class', () => {
        const primaryButton = vm.$el.querySelector('.modal-footer button:last-of-type');

        expect(primaryButton).toHaveClass(`btn-${props.footerPrimaryButtonVariant}`);
      });
    });

    describe('with footerPrimaryButtonText', () => {
      const props = {
        footerPrimaryButtonText: 'my button text',
      };

      beforeEach(() => {
        vm = mountComponent(modalComponent, props);
      });

      it('sets the primary button text', () => {
        const primaryButton = vm.$el.querySelector('.js-modal-primary-action .gl-button-text');

        expect(primaryButton.innerHTML.trim()).toBe(props.footerPrimaryButtonText);
      });
    });
  });

  it('works with data-toggle="modal"', () => {
    setFixtures(`
      <button id="modal-button" data-toggle="modal" data-target="#my-modal"></button>
      <div id="modal-container"></div>
    `);

    const modalContainer = document.getElementById('modal-container');
    const modalButton = document.getElementById('modal-button');
    vm = mountComponent(
      modalComponent,
      {
        id: 'my-modal',
      },
      modalContainer,
    );
    const modalElement = document.getElementById('my-modal');

    modalButton.click();

    expect(modalElement).not.toHaveClass('show');

    // let the modal fade in
    jest.runOnlyPendingTimers();

    expect(modalElement).toHaveClass('show');
  });

  describe('methods', () => {
    const dummyEvent = 'not really an event';

    beforeEach(() => {
      vm = mountComponent(modalComponent, {});
      jest.spyOn(vm, '$emit').mockImplementation(() => {});
    });

    describe('emitCancel', () => {
      it('emits a cancel event', () => {
        vm.emitCancel(dummyEvent);

        expect(vm.$emit).toHaveBeenCalledWith('cancel', dummyEvent);
      });
    });

    describe('emitSubmit', () => {
      it('emits a submit event', () => {
        vm.emitSubmit(dummyEvent);

        expect(vm.$emit).toHaveBeenCalledWith('submit', dummyEvent);
      });
    });

    describe('opened', () => {
      it('emits a open event', () => {
        vm.opened();

        expect(vm.$emit).toHaveBeenCalledWith('open');
      });
    });

    describe('closed', () => {
      it('emits a closed event', () => {
        vm.closed();

        expect(vm.$emit).toHaveBeenCalledWith('closed');
      });
    });
  });

  describe('slots', () => {
    const slotContent = 'this should go into the slot';

    const modalWithSlot = slot => {
      return Vue.extend({
        components: {
          DeprecatedModal2,
        },
        render: h =>
          h('deprecated-modal-2', [slot ? h('template', { slot }, slotContent) : slotContent]),
      });
    };

    describe('default slot', () => {
      beforeEach(() => {
        vm = mountComponent(modalWithSlot());
      });

      it('sets the modal body', () => {
        const modalBody = vm.$el.querySelector('.modal-body');

        expect(modalBody.innerHTML).toBe(slotContent);
      });
    });

    describe('header slot', () => {
      beforeEach(() => {
        vm = mountComponent(modalWithSlot('header'));
      });

      it('sets the modal header', () => {
        const modalHeader = vm.$el.querySelector('.modal-header');

        expect(modalHeader.innerHTML).toBe(slotContent);
      });
    });

    describe('title slot', () => {
      beforeEach(() => {
        vm = mountComponent(modalWithSlot('title'));
      });

      it('sets the modal title', () => {
        const modalTitle = vm.$el.querySelector('.modal-title');

        expect(modalTitle.innerHTML).toBe(slotContent);
      });
    });

    describe('footer slot', () => {
      beforeEach(() => {
        vm = mountComponent(modalWithSlot('footer'));
      });

      it('sets the modal footer', () => {
        const modalFooter = vm.$el.querySelector('.modal-footer');

        expect(modalFooter.innerHTML).toBe(slotContent);
      });
    });
  });

  describe('handling sizes', () => {
    it('should render modal-sm', () => {
      vm = mountComponent(modalComponent, {
        modalSize: 'sm',
      });

      expect(vm.$el.querySelector('.modal-dialog').classList.contains('modal-sm')).toEqual(true);
    });

    it('should render modal-lg', () => {
      vm = mountComponent(modalComponent, {
        modalSize: 'lg',
      });

      expect(vm.$el.querySelector('.modal-dialog').classList.contains('modal-lg')).toEqual(true);
    });

    it('should render modal-xl', () => {
      vm = mountComponent(modalComponent, {
        modalSize: 'xl',
      });

      expect(vm.$el.querySelector('.modal-dialog').classList.contains('modal-xl')).toEqual(true);
    });

    it('should not add modal size classes when md size is passed', () => {
      vm = mountComponent(modalComponent, {
        modalSize: 'md',
      });

      expect(vm.$el.querySelector('.modal-dialog').classList.contains('modal-md')).toEqual(false);
    });

    it('should not add modal size classes by default', () => {
      vm = mountComponent(modalComponent, {});

      expect(vm.$el.querySelector('.modal-dialog').classList.contains('modal-sm')).toEqual(false);
      expect(vm.$el.querySelector('.modal-dialog').classList.contains('modal-lg')).toEqual(false);
    });
  });
});
