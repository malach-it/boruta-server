import { createWebHistory, createRouter } from 'vue-router'
import oauth from './services/oauth.service'

import Main from './views/Layouts/Main.vue'

import Home from './views/Home.vue'

import OauthCallback from './views/OauthCallback.vue'

import Clients from './views/Clients.vue'
import ClientList from './views/Clients/ClientList.vue'
import NewClient from './views/Clients/NewClient.vue'
import EditClient from './views/Clients/EditClient.vue'

import Upstreams from './views/Upstreams.vue'
import UpstreamList from './views/Upstreams/UpstreamList.vue'
import NewUpstream from './views/Upstreams/NewUpstream.vue'
import EditUpstream from './views/Upstreams/EditUpstream.vue'

import RelyingParties from './views/RelyingParties.vue'
import RelyingPartyList from './views/RelyingParties/RelyingPartyList.vue'
import EditRelyingParty from './views/RelyingParties/EditRelyingParty.vue'
import EditSessionTemplate from './views/RelyingParties/EditSessionTemplate.vue'
import EditNewResetPasswordTemplate from './views/RelyingParties/EditNewResetPasswordTemplate.vue'
import EditEditResetPasswordTemplate from './views/RelyingParties/EditEditResetPasswordTemplate.vue'
import EditRegistrationTemplate from './views/RelyingParties/EditRegistrationTemplate.vue'
import NewRelyingParty from './views/RelyingParties/NewRelyingParty.vue'
import UserList from './views/RelyingParties/UserList.vue'
import EditUser from './views/RelyingParties/EditUser.vue'

import Scopes from './views/Scopes.vue'
import ScopeList from './views/Scopes/ScopeList.vue'

import Dashboard from './views/Dashboard.vue'

const router = createRouter({
  history: createWebHistory(),
  linkActiveClass: 'active',
  routes: [
    {
      path: '/',
      component: Main,
      children: [
        {
          path: '',
          name: 'home',
          component: Home
        }, {
          path: '/oauth-callback',
          name: 'oauth-callback',
          component: OauthCallback
        }, {
          path: '/dashboard',
          name: 'dashboard',
          component: Dashboard
        }, {
          path: '/relying-parties',
          component: RelyingParties,
          name: 'relying-parties',
          redirect: '/relying-parties/',
          children: [
            {
              path: '',
              name: 'relying-party-list',
              component: RelyingPartyList
            }, {
              path: 'new',
              name: 'new-relying-party',
              component: NewRelyingParty
            }, {
              path: '/relying-parties/:relyingPartyId/edit',
              name: 'edit-relying-party',
              component: EditRelyingParty
            }, {
              path: '/relying-parties/:relyingPartyId/edit/session-template',
              name: 'edit-session-template',
              component: EditSessionTemplate
            }, {
              path: '/relying-parties/:relyingPartyId/edit-send-reset-password-instructions-template',
              name: 'edit-new-reset-password-template',
              component: EditNewResetPasswordTemplate
            }, {
              path: '/relying-parties/:relyingPartyId/edit-reset-password-template',
              name: 'edit-edit-reset-password-template',
              component: EditEditResetPasswordTemplate
            }, {
              path: '/relying-parties/:relyingPartyId/edit/registration-template',
              name: 'edit-registration-template',
              component: EditRegistrationTemplate
            }, {
              path: 'users',
              name: 'user-list',
              component: UserList
            }, {
              path: '/users/:userId/edit',
              name: 'edit-user',
              component: EditUser
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
              path: '/clients/:clientId/edit',
              name: 'edit-client',
              component: EditClient
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
              path: '/upstreams/:upstreamId/edit',
              name: 'edit-upstream',
              component: EditUpstream
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
    return next(false)
  }

  return next()
})

export default router
