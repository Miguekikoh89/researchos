import { Controller, Get, Patch, Delete, Param, Body, UseGuards, Request } from '@nestjs/common';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../auth/jwt.guard';

@Controller('admin')
@UseGuards(JwtAuthGuard)
export class AdminController {
  constructor(private adminService: AdminService) {}

  @Get('stats')
  getStats(@Request() req: any) {
    return this.adminService.getStats(req.user.id);
  }

  @Get('users')
  getUsers(@Request() req: any) {
    return this.adminService.getUsers(req.user.id);
  }

  @Get('activity')
  getActivity(@Request() req: any) {
    return this.adminService.getActivity(req.user.id);
  }

  @Patch('users/:id/role')
  updateRole(@Param('id') id: string, @Body() body: { role: string }, @Request() req: any) {
    return this.adminService.updateRole(req.user.id, id, body.role);
  }

  @Patch('users/:id/status')
  updateStatus(@Param('id') id: string, @Body() body: { active: boolean }, @Request() req: any) {
    return this.adminService.updateStatus(req.user.id, id, body.active);
  }

  @Get('metrics')
  getMetrics(@Request() req: any) {
    return this.adminService.getMetrics(req.user.id);
  }

  @Get('logs')
  getLogs(@Request() req: any) {
    return this.adminService.getLogs(req.user.id);
  }

  @Get('users/:id/analyses')
  getUserAnalyses(@Param('id') id: string, @Request() req: any) {
    return this.adminService.getUserAnalyses(req.user.id, id);
  }

  @Patch('users/:id/active')
  toggleActive(@Param('id') id: string, @Body() body: { active: boolean }, @Request() req: any) {
    return this.adminService.toggleUserActive(req.user.id, id, body.active);
  }

  @Delete('users/:id')
  deleteUser(@Param('id') id: string, @Request() req: any) {
    return this.adminService.deleteUser(req.user.id, id);
  }
}
