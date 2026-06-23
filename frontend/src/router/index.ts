import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('../views/Login.vue'),
  },
  {
    path: '/',
    component: () => import('../components/Layout.vue'),
    meta: { requiresAuth: true },
    children: [
      { path: '', name: 'Dashboard', component: () => import('../views/Dashboard.vue') },
      { path: 'subscriptions', name: 'Subscriptions', component: () => import('../views/Subscriptions.vue') },
      { path: 'nodes', name: 'Nodes', component: () => import('../views/Nodes.vue') },
      { path: 'statistics', name: 'Statistics', component: () => import('../views/Statistics.vue') },
      { path: 'compare', name: 'Compare', component: () => import('../views/Compare.vue') },
      { path: 'performance', name: 'Performance', component: () => import('../views/Performance.vue') },
      { path: 'groups', name: 'Groups', component: () => import('../views/Groups.vue') },
      { path: 'favorites', name: 'Favorites', component: () => import('../views/Favorites.vue') },
      { path: 'tags', name: 'Tags', component: () => import('../views/Tags.vue') },
      { path: 'convert', name: 'Convert', component: () => import('../views/Convert.vue') },
      { path: 'users', name: 'Users', component: () => import('../views/Users.vue') },
      { path: 'apikeys', name: 'APIKeys', component: () => import('../views/APIKeys.vue') },
      { path: 'monitor', name: 'Monitor', component: () => import('../views/Monitor.vue') },
      { path: 'update', name: 'Update', component: () => import('../views/Update.vue') },
      { path: 'settings', name: 'Settings', component: () => import('../views/Settings.vue') },
    ],
  },
  { path: '/:pathMatch(.*)*', name: 'NotFound', component: () => import('../views/NotFound.vue') },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach((to, _from, next) => {
  const auth = useAuthStore()
  // Check if any matched route requires auth (handles nested routes)
  const requiresAuth = to.matched.some(record => record.meta.requiresAuth)
  if (requiresAuth && !auth.isLoggedIn) {
    next('/login')
  } else if (to.path === '/login' && auth.isLoggedIn) {
    next('/')
  } else {
    next()
  }
})

export default router
