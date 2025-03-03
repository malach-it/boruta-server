import { createRouter, createWebHistory, RouteRecordRaw } from 'vue-router'
import HomeView from '../views/HomeView.vue'
import Siopv2View from '../views/Siopv2View.vue'
import VerifiableCredentialsIssuanceView from '../views/VerifiableCredentialsIssuanceView.vue'

const routes: Array<RouteRecordRaw> = [
  {
    path: '/',
    name: 'home',
    component: HomeView
  },
  {
    path: '/siopv2',
    name: 'siopv2',
    component: Siopv2View
  },
  {
    path: '/preauthorized-code',
    name: 'preauthorized-code',
    component: VerifiableCredentialsIssuanceView
  },
  {
    path: '/callback',
    name: 'callback',
    component: HomeView
  },
  {
    path: '/about',
    name: 'about',
    // route level code-splitting
    // this generates a separate chunk (about.[hash].js) for this route
    // which is lazy-loaded when the route is visited.
    component: () => import(/* webpackChunkName: "about" */ '../views/AboutView.vue')
  }
]

const router = createRouter({
  history: createWebHistory('/accounts/wallet'),
  routes
})

export default router
