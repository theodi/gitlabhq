import * as types from './mutation_types';
import axios from '~/lib/utils/axios_utils';
import { visitUrl } from '~/lib/utils/url_utility';
import { deprecatedCreateFlash as createFlash } from '~/flash';
import { __ } from '~/locale';
import { NEW_VERSION_FLAG } from '../../constants';
import { mapFromScopesViewModel, mapStrategiesToRails } from '../helpers';

/**
 * Handles the edition of a feature flag.
 *
 * Will dispatch `requestUpdateFeatureFlag`
 * Serializes the params and makes a put request
 * Dispatches an action acording to the request status.
 *
 * @param {Object} params
 */
export const updateFeatureFlag = ({ state, dispatch }, params) => {
  dispatch('requestUpdateFeatureFlag');

  axios
    .put(
      state.endpoint,
      params.version === NEW_VERSION_FLAG
        ? mapStrategiesToRails(params)
        : mapFromScopesViewModel(params),
    )
    .then(() => {
      dispatch('receiveUpdateFeatureFlagSuccess');
      visitUrl(state.path);
    })
    .catch(error => dispatch('receiveUpdateFeatureFlagError', error.response.data));
};

export const requestUpdateFeatureFlag = ({ commit }) => commit(types.REQUEST_UPDATE_FEATURE_FLAG);
export const receiveUpdateFeatureFlagSuccess = ({ commit }) =>
  commit(types.RECEIVE_UPDATE_FEATURE_FLAG_SUCCESS);
export const receiveUpdateFeatureFlagError = ({ commit }, error) =>
  commit(types.RECEIVE_UPDATE_FEATURE_FLAG_ERROR, error);

/**
 * Fetches the feature flag data for the edit form
 */
export const fetchFeatureFlag = ({ state, dispatch }) => {
  dispatch('requestFeatureFlag');

  axios
    .get(state.endpoint)
    .then(({ data }) => dispatch('receiveFeatureFlagSuccess', data))
    .catch(() => dispatch('receiveFeatureFlagError'));
};

export const requestFeatureFlag = ({ commit }) => commit(types.REQUEST_FEATURE_FLAG);
export const receiveFeatureFlagSuccess = ({ commit }, response) =>
  commit(types.RECEIVE_FEATURE_FLAG_SUCCESS, response);
export const receiveFeatureFlagError = ({ commit }) => {
  commit(types.RECEIVE_FEATURE_FLAG_ERROR);
  createFlash(__('Something went wrong on our end. Please try again!'));
};

export const toggleActive = ({ commit }, active) => commit(types.TOGGLE_ACTIVE, active);
