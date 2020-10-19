import { escape } from 'lodash';
import { mount, createLocalVue } from '@vue/test-utils';
import createStore from '~/notes/stores';
import issueNote from '~/notes/components/noteable_note.vue';
import NoteHeader from '~/notes/components/note_header.vue';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import NoteActions from '~/notes/components/note_actions.vue';
import NoteBody from '~/notes/components/note_body.vue';
import { noteableDataMock, notesDataMock, note } from '../mock_data';

jest.mock('~/vue_shared/mixins/gl_feature_flags_mixin', () => () => ({
  inject: {
    glFeatures: {
      from: 'glFeatures',
      default: () => ({ multilineComments: true }),
    },
  },
}));

describe('issue_note', () => {
  let store;
  let wrapper;
  const findMultilineComment = () => wrapper.find('[data-testid="multiline-comment"]');

  beforeEach(() => {
    store = createStore();
    store.dispatch('setNoteableData', noteableDataMock);
    store.dispatch('setNotesData', notesDataMock);

    const localVue = createLocalVue();
    wrapper = mount(localVue.extend(issueNote), {
      store,
      propsData: {
        note,
      },
      localVue,
      stubs: [
        'note-header',
        'user-avatar-link',
        'note-actions',
        'note-body',
        'multiline-comment-form',
      ],
    });
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('mutiline comments', () => {
    it('should render if has multiline comment', () => {
      const position = {
        line_range: {
          start: {
            line_code: 'abc_1_1',
            type: null,
            old_line: '1',
            new_line: '1',
          },
          end: {
            line_code: 'abc_2_2',
            type: null,
            old_line: '2',
            new_line: '2',
          },
        },
      };
      const line = {
        line_code: 'abc_1_1',
        type: null,
        old_line: '1',
        new_line: '1',
      };
      wrapper.setProps({
        note: { ...note, position },
        discussionRoot: true,
        line,
      });

      return wrapper.vm.$nextTick().then(() => {
        expect(findMultilineComment().text()).toEqual('Comment on lines 1 to 2');
      });
    });

    it('should only render if it has everything it needs', () => {
      const position = {
        line_range: {
          start: {
            line_code: 'abc_1_1',
            type: null,
            old_line: '',
            new_line: '',
          },
          end: {
            line_code: 'abc_2_2',
            type: null,
            old_line: '2',
            new_line: '2',
          },
        },
      };
      const line = {
        line_code: 'abc_1_1',
        type: null,
        old_line: '1',
        new_line: '1',
      };
      wrapper.setProps({
        note: { ...note, position },
        discussionRoot: true,
        line,
      });

      return wrapper.vm.$nextTick().then(() => {
        expect(findMultilineComment().exists()).toBe(false);
      });
    });

    it('should not render if has single line comment', () => {
      const position = {
        line_range: {
          start: {
            line_code: 'abc_1_1',
            type: null,
            old_line: '1',
            new_line: '1',
          },
          end: {
            line_code: 'abc_1_1',
            type: null,
            old_line: '1',
            new_line: '1',
          },
        },
      };
      const line = {
        line_code: 'abc_1_1',
        type: null,
        old_line: '1',
        new_line: '1',
      };
      wrapper.setProps({
        note: { ...note, position },
        discussionRoot: true,
        line,
      });

      return wrapper.vm.$nextTick().then(() => {
        expect(findMultilineComment().exists()).toBe(false);
      });
    });

    it('should not render if `line_range` is unavailable', () => {
      expect(findMultilineComment().exists()).toBe(false);
    });
  });

  it('should render user information', () => {
    const { author } = note;
    const avatar = wrapper.find(UserAvatarLink);
    const avatarProps = avatar.props();

    expect(avatarProps.linkHref).toBe(author.path);
    expect(avatarProps.imgSrc).toBe(author.avatar_url);
    expect(avatarProps.imgAlt).toBe(author.name);
    expect(avatarProps.imgSize).toBe(40);
  });

  it('should render note header content', () => {
    const noteHeader = wrapper.find(NoteHeader);
    const noteHeaderProps = noteHeader.props();

    expect(noteHeaderProps.author).toEqual(note.author);
    expect(noteHeaderProps.createdAt).toEqual(note.created_at);
    expect(noteHeaderProps.noteId).toEqual(note.id);
  });

  it('should render note actions', () => {
    const { author } = note;
    const noteActions = wrapper.find(NoteActions);
    const noteActionsProps = noteActions.props();

    expect(noteActionsProps.authorId).toBe(author.id);
    expect(noteActionsProps.noteId).toBe(note.id);
    expect(noteActionsProps.noteUrl).toBe(note.noteable_note_url);
    expect(noteActionsProps.accessLevel).toBe(note.human_access);
    expect(noteActionsProps.canEdit).toBe(note.current_user.can_edit);
    expect(noteActionsProps.canAwardEmoji).toBe(note.current_user.can_award_emoji);
    expect(noteActionsProps.canDelete).toBe(note.current_user.can_edit);
    expect(noteActionsProps.canReportAsAbuse).toBe(true);
    expect(noteActionsProps.canResolve).toBe(false);
    expect(noteActionsProps.reportAbusePath).toBe(note.report_abuse_path);
    expect(noteActionsProps.resolvable).toBe(false);
    expect(noteActionsProps.isResolved).toBe(false);
    expect(noteActionsProps.isResolving).toBe(false);
    expect(noteActionsProps.resolvedBy).toEqual({});
  });

  it('should render issue body', () => {
    const noteBody = wrapper.find(NoteBody);
    const noteBodyProps = noteBody.props();

    expect(noteBodyProps.note).toEqual(note);
    expect(noteBodyProps.line).toBe(null);
    expect(noteBodyProps.canEdit).toBe(note.current_user.can_edit);
    expect(noteBodyProps.isEditing).toBe(false);
    expect(noteBodyProps.helpPagePath).toBe('');
  });

  it('prevents note preview xss', done => {
    const imgSrc = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
    const noteBody = `<img src="${imgSrc}" onload="alert(1)" />`;
    const alertSpy = jest.spyOn(window, 'alert');
    store.hotUpdate({
      actions: {
        updateNote() {},
        setSelectedCommentPositionHover() {},
      },
    });
    const noteBodyComponent = wrapper.find(NoteBody);

    noteBodyComponent.vm.$emit('handleFormUpdate', noteBody, null, () => {});

    setImmediate(() => {
      expect(alertSpy).not.toHaveBeenCalled();
      expect(wrapper.vm.note.note_html).toEqual(escape(noteBody));
      done();
    });
  });

  describe('cancel edit', () => {
    it('restores content of updated note', done => {
      const updatedText = 'updated note text';
      store.hotUpdate({
        actions: {
          updateNote() {},
        },
      });
      const noteBody = wrapper.find(NoteBody);
      noteBody.vm.resetAutoSave = () => {};

      noteBody.vm.$emit('handleFormUpdate', updatedText, null, () => {});

      wrapper.vm
        .$nextTick()
        .then(() => {
          const noteBodyProps = noteBody.props();

          expect(noteBodyProps.note.note_html).toBe(updatedText);
          noteBody.vm.$emit('cancelForm');
        })
        .then(() => wrapper.vm.$nextTick())
        .then(() => {
          const noteBodyProps = noteBody.props();

          expect(noteBodyProps.note.note_html).toBe(note.note_html);
        })
        .then(done)
        .catch(done.fail);
    });
  });
});
