import { s__ } from '~/locale';

export const SUCCESS = 'success';
export const WARNING = 'warning';
export const DANGER = 'danger';
export const INFO = 'info';

export const WARNING_MESSAGE_CLASS = 'warning_message';
export const DANGER_MESSAGE_CLASS = 'danger_message';

export const MWPS_MERGE_STRATEGY = 'merge_when_pipeline_succeeds';
export const MTWPS_MERGE_STRATEGY = 'add_to_merge_train_when_pipeline_succeeds';
export const MT_MERGE_STRATEGY = 'merge_train';

export const AUTO_MERGE_STRATEGIES = [MWPS_MERGE_STRATEGY, MTWPS_MERGE_STRATEGY, MT_MERGE_STRATEGY];

// SP - "Suggest Pipelines"
export const SP_TRACK_LABEL = 'no_pipeline_noticed';
export const SP_LINK_TRACK_EVENT = 'click_link';
export const SP_SHOW_TRACK_EVENT = 'click_button';
export const SP_LINK_TRACK_VALUE = 30;
export const SP_SHOW_TRACK_VALUE = 10;
export const SP_HELP_CONTENT = s__(
  `mrWidget|Use %{linkStart}CI pipelines to test your code%{linkEnd} by simply adding a GitLab CI configuration file to your project. It only takes a minute to make your code more secure and robust.`,
);
export const SP_HELP_URL = 'https://about.gitlab.com/blog/2019/07/12/guide-to-ci-cd-pipelines/';
export const SP_ICON_NAME = 'status_notfound';
