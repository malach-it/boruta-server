import { createRouter, createWebHistory, RouteRecordRaw } from 'vue-router'
import HomeView from '../views/HomeView.vue'
import Oid4vcCallbackView from '../views/Oid4vcCallbackView.vue'

const routes: Array<RouteRecordRaw> = [
  {
    path: '/credentials',
    name: 'home',
    component: HomeView
  },
  {
    path: '/',
    name: 'oid4vc-callback',
    component: Oid4vcCallbackView
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
