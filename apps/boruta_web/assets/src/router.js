import Vue from 'vue'
import Router from 'vue-router'

import Home from './views/Home.vue'

import OauthCallback from './views/OauthCallback.vue'

import Clients from './views/Clients.vue'
import ClientList from './views/ClientList.vue'
import NewClient from './views/NewClient.vue'
import EditClient from './views/EditClient.vue'

import Users from './views/Users.vue'
import UserList from './views/UserList.vue'

import Scopes from './views/Scopes.vue'
import ScopeList from './views/ScopeList.vue'

Vue.use(Router)

const router = new Router({
  mode: 'history',
  base: '/admin',
  routes: [
    {
      path: '/',
      name: 'home',
      component: Home
    }, {
      path: '/oauth-callback',
      name: 'oauth-callback',
      component: OauthCallback
    }, {
      path: '/users',
      component: Users,
      children: [
        {
          path: '',
          name: 'user-list',
          component: UserList
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
})

export default router
