import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../common/prisma.service';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
  ) {}

  async register(
    name: string,
    email: string,
    password: string,
    role: 'STUDENT' | 'ADVISOR' = 'STUDENT',
  ) {
    if (!name || !email || !password)
      throw new BadRequestException('Nombre, email y contraseña son requeridos');
    if (password.length < 8)
      throw new BadRequestException('La contraseña debe tener al menos 8 caracteres');

    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new ConflictException('El email ya está registrado');

    const hash = await bcrypt.hash(password, 12);
    const user = await this.prisma.user.create({
      data: { name, email, password: hash, role },
      select: { id: true, name: true, email: true, role: true, createdAt: true },
    });

    const token = this.jwt.sign({ sub: user.id, email: user.email, role: user.role });
    return { user, token };
  }

  async login(email: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException('Credenciales incorrectas');

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) throw new UnauthorizedException('Credenciales incorrectas');

    const { password: _pw, ...safeUser } = user;
    const token = this.jwt.sign({ sub: user.id, email: user.email, role: user.role });
    return { user: safeUser, token };
  }
}
