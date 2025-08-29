import { createRouter, createWebHistory, RouteRecordRaw } from 'vue-router'

import HomeView from '../views/HomeView.vue'
import VerifiableCredentialsIssuanceView from '../views/VerifiableCredentialsIssuanceView.vue'
import VerifiablePresentationsView from '../views/VerifiablePresentationsView.vue'
import AgentCodeView from '../views/AgentCodeView.vue'

const routes: Array<RouteRecordRaw> = [
  {
    path: '/',
    name: 'home',
    component: HomeView
  },
  {
    path: '/preauthorized-code',
    name: 'preauthorized-code',
    component: VerifiableCredentialsIssuanceView
  },
  {
    path: '/verifiable-presentation',
    name: 'verifiable-presentation',
    component: VerifiablePresentationsView
  },
  {
    path: '/agent-code',
    name: 'agent-code',
    component: AgentCodeView
  },
  {
    path: '/callback',
    name: 'callback',
    component: HomeView
  }
]

const router = createRouter({
  history: createWebHistory('/accounts/wallet'),
  routes
})

export default router
