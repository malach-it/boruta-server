import { createWebHistory, createRouter } from 'vue-router'
import oauth from './services/oauth.service'

import Main from './views/Layouts/Main.vue'

import Home from './views/Home.vue'

import OauthCallback from './views/OauthCallback.vue'
import NotFound from './views/NotFound.vue'
import BadRequest from './views/BadRequest.vue'

import Clients from './views/Clients.vue'
import ClientList from './views/Clients/ClientList.vue'
import NewClient from './views/Clients/NewClient.vue'
import Client from './views/Clients/Client.vue'
import EditClient from './views/Clients/EditClient.vue'

import Upstreams from './views/Upstreams.vue'
import UpstreamList from './views/Upstreams/UpstreamList.vue'
import Upstream from './views/Upstreams/Upstream.vue'
import NewUpstream from './views/Upstreams/NewUpstream.vue'
import EditUpstream from './views/Upstreams/EditUpstream.vue'

import IdentityProviders from './views/IdentityProviders.vue'
import IdentityProviderList from './views/IdentityProviders/IdentityProviderList.vue'
import IdentityProvider from './views/IdentityProviders/IdentityProvider.vue'
import EditIdentityProvider from './views/IdentityProviders/EditIdentityProvider.vue'
import EditLayoutTemplate from './views/IdentityProviders/EditLayoutTemplate.vue'
import EditSessionTemplate from './views/IdentityProviders/EditSessionTemplate.vue'
import EditNewChooseSessionTemplate from './views/IdentityProviders/EditNewChooseSessionTemplate.vue'
import EditNewConsentTemplate from './views/IdentityProviders/EditNewConsentTemplate.vue'
import EditNewConfirmationTemplate from './views/IdentityProviders/EditNewConfirmationTemplate.vue'
import EditNewResetPasswordTemplate from './views/IdentityProviders/EditNewResetPasswordTemplate.vue'
import EditEditResetPasswordTemplate from './views/IdentityProviders/EditEditResetPasswordTemplate.vue'
import EditRegistrationTemplate from './views/IdentityProviders/EditRegistrationTemplate.vue'
import EditEditUserTemplate from './views/IdentityProviders/EditEditUserTemplate.vue'
import NewIdentityProvider from './views/IdentityProviders/NewIdentityProvider.vue'
import Users from './views/IdentityProviders/Users.vue'
import UserList from './views/IdentityProviders/UserList.vue'
import EditUser from './views/IdentityProviders/EditUser.vue'

import Scopes from './views/Scopes.vue'
import ScopeList from './views/Scopes/ScopeList.vue'

import Configuration from './views/Configuration.vue'
import ErrorTemplateList from './views/Configuration/ErrorTemplateList.vue'
import EditBadRequestTemplate from './views/Configuration/EditBadRequestTemplate.vue'
import EditNotFoundTemplate from './views/Configuration/EditNotFoundTemplate.vue'
import EditForbiddenTemplate from './views/Configuration/EditForbiddenTemplate.vue'
import EditInternalServerErrorTemplate from './views/Configuration/EditInternalServerErrorTemplate.vue'

import Dashboard from './views/Dashboard.vue'
import Requests from './views/Dashboard/Requests.vue'
import BusinessEvents from './views/Dashboard/BusinessEvents.vue'

const router = createRouter({
  history: createWebHistory(),
  linkActiveClass: 'active',
  routes: [
    {
      path: '/',
      component: Main,
      name: 'root',
      redirect: '/',
      children: [
        {
          path: '',
          name: 'home',
          component: Home
        }, {
          path: 'not-found',
          name: 'not-found',
          component: NotFound
        }, {
          path: 'bad-request',
          name: 'bad-request',
          component: BadRequest
        }, {
          path: '/oauth-callback',
          name: 'oauth-callback',
          component: OauthCallback
        }, {
          path: '/dashboard',
          name: 'dashboard',
          component: Dashboard,
          redirect: '/dashboard/requests',
          children: [
            {
              path: 'requests',
              name: 'request-logs',
              component: Requests
            }, {
              path: 'business-events',
              name: 'business-event-logs',
              component: BusinessEvents
            }
          ]
        }, {
          path: '/identity-providers',
          component: IdentityProviders,
          name: 'identity-providers',
          redirect: '/identity-providers/',
          children: [
            {
              path: '',
              name: 'identity-provider-list',
              component: IdentityProviderList
            }, {
              path: 'new',
              name: 'new-identity-provider',
              component: NewIdentityProvider
            }, {
              path: '/identity-providers/:identityProviderId',
              name: 'identity-provider',
              component: IdentityProvider,
              redirect: to => ({
                name: 'edit-identity-provider',
                params: { identityProviderId: to.params.identityProviderId }
              }),
              children: [
                {
                  path: 'edit',
                  name: 'edit-identity-provider',
                  component: EditIdentityProvider
                }, {
                  path: 'edit/choose-session-template',
                  name: 'edit-choose-session-template',
                  component: EditNewChooseSessionTemplate
                }, {
                  path: 'edit/layout-template',
                  name: 'edit-layout-template',
                  component: EditLayoutTemplate
                }, {
                  path: 'edit/session-template',
                  name: 'edit-session-template',
                  component: EditSessionTemplate
                }, {
                  path: 'edit/registration-template',
                  name: 'edit-registration-template',
                  component: EditRegistrationTemplate
                }, {
                  path: 'edit/edit-user-template',
                  name: 'edit-edit-user-template',
                  component: EditEditUserTemplate
                }, {
                  path: 'edit/send-reset-password-instructions-template',
                  name: 'edit-new-reset-password-template',
                  component: EditNewResetPasswordTemplate
                }, {
                  path: 'edit/reset-password-template',
                  name: 'edit-edit-reset-password-template',
                  component: EditEditResetPasswordTemplate
                }, {
                  path: 'edit/consent-template',
                  name: 'edit-new-consent-template',
                  component: EditNewConsentTemplate
                }, {
                  path: 'edit/send-confirmation-instructions-template',
                  name: 'edit-new-confirmation-template',
                  component: EditNewConfirmationTemplate
                }
              ],
            }, {
              path: 'users',
              name: 'users',
              component: Users,
              redirect: '/identity-providers/users/',
              children: [
                {
                  path: '',
                  name: 'user-list',
                  component: UserList
                }, {
                  path: '/users/:userId/edit',
                  name: 'edit-user',
                  component: EditUser
                }
              ]
            }
          ]
        }, {
          path: '/clients',
          component: Clients,
          name: 'clients',
          redirect: '/clients/',
          children: [
            {
              path: '',
              name: 'client-list',
              component: ClientList
            }, {
              path: '/clients/new',
              name: 'new-client',
              component: NewClient
            }, {
              path: '/clients/:clientId',
              name: 'client',
              component: Client,
              redirect: to => ({
                name: 'edit-client',
                params: { clientId: to.params.clientId }
              }),
              children: [
                {
                  path: 'edit',
                  name: 'edit-client',
                  component: EditClient
                }
              ]
            }
          ]
        }, {
          path: '/upstreams',
          component: Upstreams,
          name: 'upstreams',
          redirect: '/upstreams/',
          children: [
            {
              path: '',
              name: 'upstream-list',
              component: UpstreamList
            }, {
              path: '/upstreams/new',
              name: 'new-upstream',
              component: NewUpstream
            }, {
              path: '/upstreams/:upstreamId',
              name: 'upstream',
              component: Upstream,
              redirect: to => ({
                name: 'edit-upstream',
                params: { upstreamId: to.params.upstreamId }
              }),
              children: [
                {
                  path: 'edit',
                  name: 'edit-upstream',
                  component: EditUpstream
                }
              ]
            }
          ]
        }, {
          path: '/scopes',
          component: Scopes,
          name: 'scopes',
          redirect: '/scopes/',
          children: [
            {
              path: '',
              name: '',
              component: ScopeList
            }
          ]
        }, {
          path: '/configuration',
          component: Configuration,
          name: 'configuration',
          redirect: '/configuration/error-template-list',
          children: [
            {
              path: '',
              name: '',
              component: Configuration
            }, {
              path: 'error-template-list',
              name: 'error-template-list',
              component: ErrorTemplateList
            }, {
              path: 'edit-bad-request-template',
              name: 'edit-bad-request-template',
              component: EditBadRequestTemplate
            }, {
              path: 'edit-forbidden-template',
              name: 'edit-forbidden-template',
              component: EditForbiddenTemplate
            }, {
              path: 'edit-not-found-template',
              name: 'edit-not-found-template',
              component: EditNotFoundTemplate
            }, {
              path: 'edit-internal-server-error-template',
              name: 'edit-internal-server-error-template',
              component: EditInternalServerErrorTemplate
            }
          ]
        }, {
          path: '/:pathMatch(.*)*',
          component: NotFound
        }
      ]
    }
  ]
})

router.beforeEach((to, from, next) => {
  if (to.name === 'oauth-callback') return next()

  if (to.name) oauth.storeLocationName(to.name, to.params)

  if (!oauth.isAuthenticated) {
    // TODO find a way to remove event listener once triggered
    window.addEventListener('logged_in', () => { next() })

    oauth.silentRefresh()
  } else {
    return next()
  }
})

export default router
