<script setup>
import { VideoPlay, CircleClose, Refresh, Warning } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
</script>
  
<template>
  <el-row style="margin-top: 8px;">
    <el-col :span="12" align="left">

      <!-- Update -->
      <el-button class="button-control" type='primary' :icon="Warning" round @click="updateRepo()">
        Update
      </el-button>

      <!-- Build -->
      <el-button class="button-control" type='primary' :icon="Warning" round @click="buildRepo()">
        Build
      </el-button>

    </el-col>
    <el-col :span="12" align="right">

      <el-divider direction="vertical" content-position="center" />

      <!-- Status -->
      <el-button class="button-control" type='primary' :icon="Warning" round @click="serviceStatus()">
        Status
      </el-button>

      <el-divider direction="vertical" content-position="center" />

      <!-- Reboot All -->
      <el-popover placement="top" trigger="focus" :width="180">
        <p>Operation conformation</p>
        <div style="text-align: right; margin-top: 8px;">
          <el-button size="small" type='warning' round @click="rebootAll()" style="width: 100%" :loading="isLoading">
            Confirm to Reboot
          </el-button>
        </div>
        <template #reference>
          <el-button class="button-control" type='warning' :icon="Refresh" round>
            Reboot
          </el-button>
        </template>
      </el-popover>

      <!-- Run All -->
      <el-popover placement="top" trigger="focus" :width="180">
        <p>Operation conformation</p>
        <div style="text-align: right; margin-top: 8px;">
          <el-button size="small" type='success' round @click="runAll()" style="width: 100%" :loading="isLoading">
            Confirm to Boot
          </el-button>
        </div>
        <template #reference>
          <el-button class="button-control" type='success' :icon="VideoPlay" round>
            Boot
          </el-button>
        </template>
      </el-popover>

      <!-- Kill All -->
      <el-popover placement="top" trigger="focus" :width="180">
        <p>Operation conformation</p>
        <div style="text-align: right; margin-top: 8px;">
          <el-button size="small" type='danger' round @click="killAll()" style="width: 100%" :loading="isLoading">
            Confirm to Stop
          </el-button>
        </div>
        <template #reference>
          <el-button class="button-control" type='danger' :icon="CircleClose" round>
            Stop
          </el-button>
        </template>
      </el-popover>

    </el-col>
  </el-row>
</template>
  
<script>
import { useMainStorage } from '../stores/main.js'
export default {
  name: 'ServiceControlPanel',
  props: {
    onFetchList: Function,
    onServiceLog: Function,
    data: Object,
  },
  data: () => {
    return {
      isLoading: false,
    }
  },
  mounted() {
    this.main = useMainStorage()
  },
  beforeUnmount() {
  },
  methods: {

    serviceStatus() {
      if (this.isLoading) { return }
      this.onServiceLog("Checking service status...")
      this.isLoading = true
      this.main.sendActionRequest("/api/service", "statusAll", null, null, (success, error, message, data) => {
        if (error == null) {
          this.onServiceLog(message)
        } else {
          this.onServiceLog(message)
        }
        this.isLoading = false
      })
    },

    runAll() {
      if (this.isLoading) { return }
      this.onServiceLog("Booting all services...")
      this.isLoading = true
      this.main.sendActionRequest("/api/service", "runAll", null, null, (success, error, message, data) => {
        if (error == null) {
          this.onServiceLog(message)
          this.onFetchList()
        } else {
          this.onServiceLog(message)
        }
        this.isLoading = false
      })
    },

    killAll() {
      if (this.isLoading) { return }
      this.onServiceLog("Killing all services...")
      this.isLoading = true
      this.main.sendActionRequest("/api/service", "killAll", null, null, (success, error, message, data) => {
        if (error == null) {
          this.onServiceLog(message)
          this.onFetchList()
        } else {
          this.onServiceLog(message)
        }
        this.isLoading = false
      })
    },

    rebootAll() {
      if (this.isLoading) { return }
      this.onServiceLog("Rebooting all services...")
      this.isLoading = true
      this.main.sendActionRequest("/api/service", "rebootAll", null, null, (success, error, message, data) => {
        if (error == null) {
          this.onServiceLog(message)
          this.onFetchList()
        } else {
          this.onServiceLog(message)
        }
        this.isLoading = false
      })
    },

    updateRepo() {
    },

    buildRepo() {
    },
  }
}
</script>
  
<style>
.table {
  margin: 12px;
}

.action {
  width: 72px
}

.status {
  width: 66px
}

.button-control {
  width: 88px
}
</style>
