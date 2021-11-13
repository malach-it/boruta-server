import Vue from 'vue'
import Router from 'vue-router'
import oauth from '@/services/oauth.service'

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

import Users from './views/Users.vue'
import UserList from './views/Users/UserList.vue'
import EditUser from './views/Users/EditUser.vue'

import Scopes from './views/Scopes.vue'
import ScopeList from './views/Scopes/ScopeList.vue'

import Dashboard from './views/Dashboard.vue'

Vue.use(Router)

const router = new Router({
  mode: 'history',
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
          path: '/users',
          component: Users,
          children: [
            {
              path: 'list',
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
          children: [
            {
              path: '',
              name: 'scope-list',
              component: ScopeList
            }
          ]
        }
      ]
    }
  ]
})

router.beforeEach((to, from, next) => {
  if (to.name && to.name !== 'oauth-callback') oauth.storeLocationName(to.name)

  next()
})

export default router
