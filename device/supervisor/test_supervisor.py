#!/usr/bin/env python3
"""Pruebas del supervisor, sin movil: sistema falso y reloj virtual.

    python3 -m unittest -v bluetooth-call/supervisor/test_supervisor.py

El falso imita lo medido en el movil el 2026-09-10:
  - el kernel escribe `moving call` y reserva el canal 157 cada vez que la
    tarjeta ENTRA en Bluetooth;
  - el eSCO solo existe con el casco en CVSD y el SCO adquirido, y cambiar el
    casco de perfil suelta el SCO (bluez5-device.c: emit_remove_nodes);
  - wireplumber pone la tarjeta en el casco al empezar la llamada (`externo`),
    y callaudiod la mueve con el boton del altavoz (`externo` tambien).
  - spacewar (2026-09-15): el WCN6750 solo se enumera con el SCO en pie y despues
    sigue enumerado; sin enumerar, entrar en Bluetooth da «chip not enumerated» y no
    reserva canales; PipeWire reintenta el arranque `reintentos_seg` tras entrar.
La regla que se vigila en todas: el canal 157 NUNCA arranca dos veces seguidas.
"""
import importlib.util
import os
import unittest

_AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("sup", os.path.join(_AQUI, "supervisor-llamada-bt.py"))
S = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(S)

GUARDA = 8.0


class Reloj:
    def __init__(self):
        self.t = 1000.0

    def __call__(self):
        return self.t

    def dormir(self, d):
        self.t += d


class Falso:
    def __init__(self, reloj, nucleo):
        self.reloj, self.nucleo = reloj, nucleo
        self.movil = {"nombre": S.TARJETA_MOVIL, "perfil": "HiFi (Mic, Speaker)", "id": 68,
                      "perfiles": {S.P_MOVIL_BT: True, S.P_MOVIL_AURICULAR: True,
                                   S.P_MOVIL_ALTAVOZ: True, "HiFi (Mic, Speaker)": True}}
        self.casco = {"nombre": "bluez_card.X", "perfil": "a2dp-sink", "id": 90,
                      "perfiles": {"a2dp-sink": True, S.P_CASCO_VOZ: True}}
        self.hay_casco = True
        self.sco = False
        self.esco_posible = lambda: True
        self.acciones = []
        self.sesion = True
        self.sesiones = []          # valores escritos en switch_full_session
        self.param_0129 = True      # None = kernel sin el parche
        self.sin_sumidero = False
        self.chip_enumerado = True  # WCN6750: se enumera con el SCO en pie y luego sigue enumerado
        self.enumerable = True      # False: no aparece ni con el SCO
        self.reintentos_seg = None  # PipeWire reintenta el arranque del flujo durante N s tras entrar
        self.t_entrada_bt = None
        self.flujo = False

    def _kernel_tarjeta(self, antes, perfil, kernel=True):
        if not kernel:
            return
        t = self.reloj()
        if perfil == S.P_MOVIL_BT and antes != S.P_MOVIL_BT:
            # spacewar: el kernel escribe `moving call` aunque el flujo al chip falle
            self.nucleo.linea("q6voice-dai x: moving call: tx_port 120 -> 151, rx_port 20 -> 150", t)
            self.t_entrada_bt = t
            self._arrancar_flujo(t)
        elif antes == S.P_MOVIL_BT and perfil != S.P_MOVIL_BT:
            self.nucleo.linea("q6voice-dai x: moving call: tx_port 151 -> 120, rx_port 150 -> 20", t)
            self.flujo = False

    def _arrancar_flujo(self, t):
        if not self.chip_enumerado and self.enumerable and self.esco():
            self.chip_enumerado = True
        if self.chip_enumerado:
            self.nucleo.linea("wcn-bt-slim 217:220:1:0: bus channel 157 reserved for playback", t)
            self.nucleo.linea("wcn-bt-slim 217:220:1:0: bus channel 159 reserved for capture", t)
            self.flujo = True
        else:
            self.nucleo.linea("wcn-bt-slim 217:222:1:0: chip not enumerated", t)

    def externo(self, perfil, kernel=True):
        """Otro (wireplumber, callaudiod) cambia la tarjeta: no cuenta como accion."""
        antes, self.movil["perfil"] = self.movil["perfil"], perfil
        self._kernel_tarjeta(antes, perfil, kernel)

    def tarjetas(self):
        return {"movil": dict(self.movil),
                "casco": dict(self.casco) if self.hay_casco else None}

    def poner_perfil(self, tarjeta, perfil):
        self.acciones.append(("perfil", tarjeta, perfil))
        if tarjeta == S.TARJETA_MOVIL:
            antes, self.movil["perfil"] = self.movil["perfil"], perfil
            self._kernel_tarjeta(antes, perfil)
        else:
            if perfil != self.casco["perfil"]:
                self.sco = False
            self.casco["perfil"] = perfil
        return True

    def esco(self):
        return (self.hay_casco and self.casco["perfil"] in S.PERFILES_VOZ
                and self.sco and self.esco_posible())

    def offload(self, dev, activo):
        self.acciones.append(("offload", activo))
        self.sco = activo
        t = self.reloj()
        if (activo and not self.flujo and self.movil["perfil"] == S.P_MOVIL_BT
                and self.reintentos_seg is not None and self.t_entrada_bt is not None
                and t - self.t_entrada_bt <= self.reintentos_seg):
            self._arrancar_flujo(t)             # un reintento de PipeWire pilla el SCO en pie
        return True

    def offload_leido(self, dev):
        return self.sco

    def mezclador_bt(self):
        return self.movil["perfil"] == S.P_MOVIL_BT

    def sesion_dsp(self):
        return self.sesion

    def sumideros_casco(self):
        return (["bluez_output.X.1"] if self.hay_casco and not self.sin_sumidero
                and self.casco["perfil"].startswith("a2dp") else [])

    def mover_sonido_a(self, s, flujos=True):
        self.acciones.append(("sonido", s, flujos))
        return True

    def sesion_completa(self, activa):
        self.sesiones.append(activa)
        return self.param_0129


class Base(unittest.TestCase):
    def setUp(self):
        self.reloj = Reloj()
        self.nucleo = S.Nucleo(self.reloj)
        self.nucleo.linea("q6voice-dai x: creating cvp: tx_port=120 (afe 45111) rx_port=20", 0.0)
        self.sis = Falso(self.reloj, self.nucleo)
        self.llamadas = {}
        self.avisos = []
        self.sup = S.Supervisor(self.sis, self.nucleo, lambda: self.llamadas,
                                lambda *a: self.avisos.append(a), reloj=self.reloj,
                                dormir=self.reloj.dormir, modo="actuar",
                                max_reparaciones=3, guarda_rutas=GUARDA)

    def empezar(self, tarjeta=S.P_MOVIL_BT, kernel=True):
        """Llamada activa; wireplumber pone la tarjeta (en el casco si esta conectado)."""
        self.llamadas = {"/Call/0": S.MM_ACTIVE}
        self.reloj.t += 1
        self.sis.externo(tarjeta, kernel)

    def claves(self):
        return [a[0] for a in self.avisos]

    def montado_de_verdad(self):
        return self.sup.comprobar(self.sis.tarjetas()) is None

    def acciones_de_tarjeta(self):
        return [a for a in self.sis.acciones if a[0] == "perfil" and a[1] == S.TARJETA_MOVIL]

    def assertSinDobleArranque(self):
        arr = [x for x in self.nucleo.arranques_157 if x > 0]
        for a, b in zip(arr, arr[1:]):
            self.assertGreaterEqual(b - a, GUARDA, "canal 157 arrancado dos veces en %.1f s" % (b - a))


class Montaje(Base):
    def test_llamada_con_casco_no_mueve_la_tarjeta(self):
        self.empezar()
        self.sup.revisar()
        self.assertTrue(self.montado_de_verdad())
        self.assertEqual(self.claves(), ["montado"])
        self.assertEqual(self.acciones_de_tarjeta(), [])
        self.assertIn(("perfil", "bluez_card.X", S.P_CASCO_VOZ), self.sis.acciones)
        self.assertIn(("offload", True), self.sis.acciones)
        self.assertEqual(len([x for x in self.nucleo.arranques_157 if x > 0]), 1)

    def test_casco_sin_negociacion_de_codec_usa_headset_head_unit(self):
        # the other phone con oFono: el perfil CVSD sale sin sufijo
        self.sis.casco["perfiles"] = {"a2dp-sink": True, S.P_CASCO_VOZ_SIN_CODEC: True}
        self.empezar()
        self.sup.revisar()
        self.assertTrue(self.montado_de_verdad())
        self.assertIn(("perfil", "bluez_card.X", S.P_CASCO_VOZ_SIN_CODEC), self.sis.acciones)
        self.assertNotIn(("perfil", "bluez_card.X", S.P_CASCO_VOZ), self.sis.acciones)

    def test_segunda_pasada_no_toca_nada(self):
        self.empezar()
        self.sup.revisar()
        n = len(self.sis.acciones)
        self.sup.revisar()
        self.assertEqual(len(self.sis.acciones), n)
        self.assertEqual(self.claves(), ["montado"])

    def test_casco_conectado_a_mitad_mete_la_tarjeta_una_vez_y_el_enlace_despues(self):
        self.sis.hay_casco = False
        self.empezar(tarjeta=S.P_MOVIL_AURICULAR)
        self.sup.revisar()
        self.assertEqual(self.sis.acciones, [])
        self.reloj.t += 3
        self.sis.hay_casco = True
        self.sup.revisar()
        self.assertTrue(self.montado_de_verdad())
        orden = [a for a in self.sis.acciones if a[0] in ("offload", "perfil")]
        self.assertLess(orden.index(("perfil", S.TARJETA_MOVIL, S.P_MOVIL_BT)),
                        len(orden) - 1 - orden[::-1].index(("offload", True)))
        self.assertEqual(len(self.acciones_de_tarjeta()), 1)
        self.assertSinDobleArranque()

    def test_si_el_enlace_no_sube_se_rinde_sin_mover_la_tarjeta(self):
        self.sis.esco_posible = lambda: False
        self.empezar()
        self.sup.revisar()
        self.assertEqual(self.claves(), ["fallo", "fallo", "rendido"])
        self.assertEqual(self.avisos[-1][3], 2)
        self.assertEqual(self.acciones_de_tarjeta(), [])
        self.assertEqual(self.sis.movil["perfil"], S.P_MOVIL_BT)
        n = len(self.sis.acciones)
        self.sup.revisar()                      # rendido: no insiste
        self.assertEqual(len(self.sis.acciones), n)

    def test_supervisor_reiniciado_con_todo_montado_no_toca_nada(self):
        self.sis.casco["perfil"] = S.P_CASCO_VOZ
        self.sis.sco = True
        self.empezar()
        self.sup.revisar()
        self.assertEqual(self.sis.acciones, [])
        self.assertEqual(self.claves(), ["montado"])

    def test_entrante_sonando_no_se_monta(self):
        self.llamadas = {"/Call/0": S.MM_RINGING_IN}
        self.sup.revisar()
        self.assertEqual([a for a in self.sis.acciones if a[0] != "sonido"], [])


class Fallos(Base):
    def test_si_se_cae_el_enlace_repara_solo_el_casco(self):
        self.empezar()
        self.sup.revisar()
        self.sis.sco = False                    # se cae el eSCO
        self.sup.revisar()
        self.assertTrue(self.montado_de_verdad())
        self.assertEqual(self.claves(), ["montado", "fallo", "montado"])
        self.assertEqual(self.acciones_de_tarjeta(), [])
        self.assertSinDobleArranque()

    def test_rutas_que_fallan_con_la_tarjeta_en_el_casco_solo_se_avisan(self):
        self.empezar(kernel=False)              # la tarjeta entra pero el DSP no mueve la llamada
        self.sup.revisar()
        self.assertEqual(self.claves()[-1], "rutas")
        self.assertEqual(self.acciones_de_tarjeta(), [])
        n = len(self.sis.acciones)
        self.sup.revisar()
        self.assertEqual(len(self.sis.acciones), n)
        self.assertEqual(self.claves().count("rutas"), 1)

    def test_casco_desconectado_y_reconectado_vuelve_al_casco_respetando_la_guarda(self):
        self.empezar()
        self.sup.revisar()
        self.sis.hay_casco = False
        self.sup.revisar()
        self.assertEqual(self.sis.movil["perfil"], S.P_MOVIL_AURICULAR)
        self.assertEqual(self.claves()[-1], "desconectado")
        self.reloj.t += 2                       # reconecta enseguida
        self.sis.hay_casco = True
        self.sis.casco["perfil"] = "a2dp-sink"
        self.sis.sco = False
        self.sup.revisar()
        self.assertEqual(self.sis.movil["perfil"], S.P_MOVIL_BT)
        self.assertTrue(self.montado_de_verdad())
        self.assertSinDobleArranque()

    def test_doble_arranque_de_otro_se_avisa(self):
        self.empezar()
        self.reloj.t += 1.3
        self.nucleo.linea("wcn-bt-slim 217:220:1:0: bus channel 157 reserved for playback", self.reloj())
        self.sup.revisar()
        self.assertIn("doble-arranque", self.claves())

    def test_error_del_bus_al_empezar_la_llamada_no_se_notifica(self):
        self.nucleo.linea("qcom,slim-ngd qcom,slim-ngd.1: Tx:MT:0x0, MC:0x60, LA:0xce failed:-110",
                          self.reloj())
        self.empezar()
        self.sup.revisar()
        self.assertTrue(self.montado_de_verdad())
        self.assertEqual(self.claves(), ["montado"])        # solo al diario

    def test_error_del_slimbus_tras_montar_es_de_rutas(self):
        self.empezar()
        self.sup.revisar()
        self.reloj.t += 5
        self.nucleo.linea("wcn-bt-slim 217:220:1:0: startup: hw rev read -> -110")
        self.assertEqual(self.sup.comprobar(self.sis.tarjetas())[0], "rutas")

    def test_si_cuelgas_mientras_monta_no_avisa_ni_sigue(self):
        self.sis.esco_posible = lambda: False
        self.empezar()
        dormir = self.reloj.dormir
        pasos = [0]

        def dormir_y_colgar(d):
            dormir(d)
            pasos[0] += 1
            if pasos[0] == 5:
                self.llamadas = {}
        self.sup.dormir = dormir_y_colgar
        self.sup.revisar()
        self.assertNotIn("fallo", self.claves())
        self.assertNotIn("rendido", self.claves())

    def test_doble_arranque_tras_el_altavoz_no_se_avisa(self):
        self.empezar()
        self.sup.revisar()
        self.reloj.t += 10
        self.sis.externo(S.P_MOVIL_ALTAVOZ)
        self.sup.revisar()
        self.reloj.t += 1
        self.sis.externo(S.P_MOVIL_BT)
        self.reloj.t += 1
        self.nucleo.linea("wcn-bt-slim 217:220:1:0: bus channel 157 reserved for playback", self.reloj())
        self.sup.revisar()
        self.assertNotIn("doble-arranque", self.claves())

    def test_tarjeta_desaparecida_no_toca_nada_y_avisa_una_vez(self):
        self.empezar()
        self.sup.revisar()
        n = len(self.sis.acciones)
        self.sis.tarjetas = lambda: {"movil": None, "casco": dict(self.sis.casco)}
        self.sup.revisar()
        self.sup.revisar()
        self.assertEqual(len(self.sis.acciones), n)
        self.assertEqual(self.claves().count("sin-tarjeta"), 1)
        self.assertFalse(self.sup.volviendo)

    def test_chip_encallado_no_toca_nada(self):
        self.nucleo.linea("Bluetooth: hci0: Retry BT power ON:2", 0.0)
        self.empezar()
        self.sup.revisar()
        self.assertEqual(self.sis.acciones, [])

    def test_modemmanager_mudo_no_toca_nada(self):
        self.empezar()
        self.sup.llamadas = lambda: None
        self.sup.revisar()
        self.assertEqual(self.sis.acciones, [])

    def test_modo_observar_no_toca_nada(self):
        self.sup.modo = "observar"
        self.empezar()
        self.sup.revisar()
        self.assertEqual(self.sis.acciones, [])
        self.assertEqual(self.avisos, [])


class FlujoCasco(Base):
    """spacewar 2026-09-15 15:24: la tarjeta entra en Bluetooth antes que el SCO."""

    def test_flujo_sin_arrancar_con_el_enlace_en_pie_saca_y_mete_la_tarjeta_una_vez(self):
        self.sis.chip_enumerado = False
        self.empezar()                          # wireplumber mete la tarjeta: chip not enumerated
        self.assertTrue(self.nucleo.flujo_casco_sin_arrancar())
        self.reloj.t += 8                       # los reintentos de PipeWire ya se han acabado
        self.sup.revisar()
        self.assertTrue(self.montado_de_verdad())
        self.assertEqual(self.claves(), ["montado"])
        self.assertEqual([a[2] for a in self.acciones_de_tarjeta()], [S.P_MOVIL_AURICULAR, S.P_MOVIL_BT])
        self.assertEqual(len([x for x in self.nucleo.arranques_157 if x > 0]), 1)
        orden = [a for a in self.sis.acciones if a[0] in ("offload", "perfil")]
        self.assertLess(orden.index(("offload", True)), orden.index(("perfil", S.TARJETA_MOVIL, S.P_MOVIL_BT)))
        n = len(self.sis.acciones)
        self.sup.revisar()                      # montado: no vuelve a tocar nada
        self.assertEqual(len(self.sis.acciones), n)

    def test_flujo_que_arranca_solo_al_subir_el_enlace_no_toca_la_tarjeta(self):
        self.sis.chip_enumerado = False
        self.sis.reintentos_seg = 7.0
        self.empezar()
        self.reloj.t += 2                       # el SCO llega mientras PipeWire reintenta
        self.sup.revisar()
        self.assertTrue(self.montado_de_verdad())
        self.assertEqual(self.claves(), ["montado"])
        self.assertEqual(self.acciones_de_tarjeta(), [])

    def test_flujo_que_no_arranca_ni_rearrancando_se_rinde_sin_arrancar_el_157(self):
        self.sis.chip_enumerado = False
        self.sis.enumerable = False
        self.empezar()
        self.reloj.t += 8
        self.sup.revisar()
        self.assertEqual(self.claves(), ["fallo", "fallo", "rendido"])
        self.assertEqual(len(self.acciones_de_tarjeta()), 2 * 3)   # una vuelta por montaje
        self.assertEqual([x for x in self.nucleo.arranques_157 if x > 0], [])
        self.assertEqual(self.sis.movil["perfil"], S.P_MOVIL_BT)
        n = len(self.sis.acciones)
        self.sup.revisar()                      # rendido: no insiste
        self.assertEqual(len(self.sis.acciones), n)

    def test_si_cuelgas_antes_del_rearranque_no_toca_la_tarjeta(self):
        self.sis.chip_enumerado = False
        self.empezar()
        self.reloj.t += 8
        dormir = self.reloj.dormir

        def dormir_y_colgar(d):
            dormir(d)
            if self.sis.sco:                    # colgada en plena espera del circuito
                self.llamadas = {}
        self.sup.dormir = dormir_y_colgar
        self.sup.revisar()
        self.assertEqual(self.acciones_de_tarjeta(), [])
        self.assertNotIn("fallo", self.claves())


class Usuario(Base):
    def _montado_y_altavoz(self):
        self.empezar()
        self.sup.revisar()
        self.reloj.t += 10
        self.sis.externo(S.P_MOVIL_ALTAVOZ)     # boton de callaudiod
        self.sup.revisar()

    def test_altavoz_pasa_el_casco_a_musica_y_la_vuelta_rehace_el_enlace(self):
        self._montado_y_altavoz()
        self.assertEqual(self.sis.casco["perfil"], "a2dp-sink")
        self.assertFalse(self.sis.sco)
        self.assertIn(("sonido", "bluez_output.X.1", False), self.sis.acciones)
        n_antes = len(self.sis.acciones)
        self.reloj.t += 15
        self.sis.externo(S.P_MOVIL_BT)          # callaudiod vuelve al casco
        self.sup.revisar()
        # la vuelta pone la salida en el casco ANTES de pasarlo a voz
        i_salida = self.sis.acciones.index(("sonido", "bluez_output.X.1", False), n_antes)
        i_voz = max(i for i, a in enumerate(self.sis.acciones) if a[0] == "perfil" and a[1] != S.TARJETA_MOVIL and a[2] == S.P_CASCO_VOZ)
        self.assertLess(i_salida, i_voz)
        self.assertEqual(self.sis.casco["perfil"], S.P_CASCO_VOZ)
        self.assertTrue(self.sis.sco)
        self.assertEqual(self.acciones_de_tarjeta(), [])
        self.assertTrue(self.montado_de_verdad())

    def test_si_el_enlace_se_perdio_en_altavoz_la_vuelta_repara_solo_el_casco(self):
        self._montado_y_altavoz()
        self.sis.sco = False
        self.reloj.t += 5
        self.sis.externo(S.P_MOVIL_BT)
        self.sup.revisar()
        self.assertTrue(self.montado_de_verdad())
        self.assertEqual(self.acciones_de_tarjeta(), [])
        self.assertSinDobleArranque()

    def test_tras_rendirse_altavoz_y_vuelta_lo_intenta_otra_vez(self):
        self.sis.esco_posible = lambda: False
        self.empezar()
        self.sup.revisar()
        self.assertEqual(self.claves()[-1], "rendido")
        self.reloj.t += 10
        self.sis.externo(S.P_MOVIL_ALTAVOZ)
        self.sup.revisar()
        self.sis.esco_posible = lambda: True
        self.reloj.t += 5
        self.sis.externo(S.P_MOVIL_BT)
        self.sup.revisar()
        self.assertTrue(self.montado_de_verdad())

    def test_sesion_completa_nunca_se_enciende(self):
        self.sup.revisar()
        self.empezar()
        self.sup.revisar()
        self.reloj.t += 10
        self.sis.externo(S.P_MOVIL_ALTAVOZ)
        self.sup.revisar()
        self.reloj.t += 10
        self.sis.externo(S.P_MOVIL_BT)
        self.sup.revisar()
        self.assertNotIn(True, self.sis.sesiones)

    def test_al_colgar_la_salida_vuelve_al_casco_con_sus_flujos(self):
        self.empezar()
        self.sup.revisar()
        self.llamadas = {}
        self.sup.revisar()
        self.assertIn(("sonido", "bluez_output.X.1", True), self.sis.acciones)

    def test_sin_sumidero_del_casco_no_se_toca_la_salida(self):
        self.sis.sin_sumidero = True
        self._montado_y_altavoz()
        self.reloj.t += 10
        self.sis.externo(S.P_MOVIL_BT)
        self.sup.revisar()
        self.llamadas = {}
        self.sup.revisar()
        self.assertEqual([a for a in self.sis.acciones if a[0] == "sonido"], [])

    def test_kernel_sin_0129_no_rompe_nada(self):
        self.sis.param_0129 = None
        self._montado_y_altavoz()
        self.reloj.t += 5
        self.sis.externo(S.P_MOVIL_BT)
        self.sup.revisar()
        self.assertTrue(self.montado_de_verdad())

    def test_fin_de_llamada_devuelve_el_casco_a_musica(self):
        self.empezar()
        self.sup.revisar()
        self.llamadas = {}
        self.sup.revisar()
        self.assertEqual(self.sis.casco["perfil"], "a2dp-sink")
        self.assertFalse(self.sis.sco)
        self.assertFalse(self.sup.en_llamada)

    def test_colgar_en_altavoz_suelta_el_casco(self):
        self._montado_y_altavoz()
        self.llamadas = {}
        self.sup.revisar()
        self.assertFalse(self.sis.sco)
        self.assertEqual(self.sis.casco["perfil"], "a2dp-sink")

    def test_sin_llamada_la_musica_salta_al_casco_una_sola_vez(self):
        self.sup.revisar()
        self.sup.revisar()
        self.assertEqual(self.sis.acciones, [("sonido", "bluez_output.X.1", True)])

    def test_sin_llamada_la_tarjeta_en_perfil_de_llamada_vuelve_a_hifi(self):
        self.sis.movil["perfil"] = S.P_MOVIL_ALTAVOZ      # restaurado tras un cuelgue
        self.sup.revisar()
        self.assertIn(("perfil", S.TARJETA_MOVIL, "HiFi (Mic, Speaker)"), self.sis.acciones)
        self.assertEqual(self.sis.movil["perfil"], "HiFi (Mic, Speaker)")

    def test_con_llamada_no_se_devuelve_a_hifi(self):
        self.sis.hay_casco = False
        self.empezar(tarjeta=S.P_MOVIL_ALTAVOZ)
        self.sup.revisar()
        self.assertNotIn(("perfil", S.TARJETA_MOVIL, "HiFi (Mic, Speaker)"), self.sis.acciones)

    def test_recien_colgada_no_pisa_a_wireplumber(self):
        self.empezar()
        self.sup.revisar()
        self.llamadas = {}
        self.sup.revisar()                      # fin de llamada; la tarjeta aun en BT
        self.assertNotIn(("perfil", S.TARJETA_MOVIL, "HiFi (Mic, Speaker)"), self.sis.acciones)
        self.reloj.t += 11
        self.sup.revisar()                      # nadie la devolvio: ahora si
        self.assertIn(("perfil", S.TARJETA_MOVIL, "HiFi (Mic, Speaker)"), self.sis.acciones)

    def test_llamada_sin_casco_no_hace_nada(self):
        self.sis.hay_casco = False
        self.empezar(tarjeta=S.P_MOVIL_AURICULAR)
        self.sup.revisar()
        self.assertEqual(self.sis.acciones, [])
        self.assertEqual(self.avisos, [])


class Lecturas(unittest.TestCase):
    def test_nucleo_con_lineas_reales(self):
        n = S.Nucleo(lambda: 5.0)
        self.assertTrue(n.linea("q6voice-dai 62400000.remoteproc:glink-edge:apr:service@9:dais: "
                                "creating cvp: tx_port=120 (afe 45111) rx_port=20 (afe 4100)"))
        self.assertEqual(n.tx, 120)
        self.assertTrue(n.linea("q6voice-dai 62400000.remoteproc:glink-edge:apr:service@9:dais: "
                                "moving call: tx_port 120 -> 151, rx_port 20 -> 150"))
        self.assertEqual(n.tx, 151)
        self.assertEqual(n.t_salida_casco, 0.0)
        self.assertTrue(n.linea("moving call: tx_port 151 -> 120, rx_port 150 -> 20", 9.0))
        self.assertEqual(n.t_salida_casco, 9.0)
        self.assertTrue(n.linea("wcn-bt-slim 217:220:1:0: bus channel 157 reserved for playback"))
        self.assertEqual(n.arranques_157, [5.0])
        self.assertFalse(n.linea("wcn-bt-slim 217:220:1:0: bus channel 159 reserved for capture"))
        self.assertFalse(n.linea("wcn-bt-slim 217:220:1:0: prepare (DSP port up): hw rev read -> 0"))
        self.assertFalse(n.linea("qcom-q6cvp aprsvc:service:4:b: command 0x112c2 failed with error 1"))
        self.assertEqual(n.t_error_slim, 0.0)

    def test_nucleo_chip_no_enumerado(self):
        n = S.Nucleo(lambda: 5.0)
        self.assertFalse(n.flujo_casco_sin_arrancar())
        self.assertTrue(n.linea("wcn-bt-slim 217:222:1:0: chip not enumerated"))
        self.assertEqual(n.t_chip_no_enumerado, 5.0)
        self.assertEqual(n.t_error_slim, 0.0)           # no es un error del bus
        self.assertTrue(n.flujo_casco_sin_arrancar())
        n.linea("wcn-bt-slim 217:222:1:0: bus channel 157 reserved for playback", 6.0)
        self.assertFalse(n.flujo_casco_sin_arrancar())
        m = S.Nucleo(lambda: 0.0)                       # lineas de antes de arrancar el supervisor
        m.linea("wcn-bt-slim 217:222:1:0: chip not enumerated", 0.0)
        self.assertFalse(m.flujo_casco_sin_arrancar())

    def test_json_de_pactl(self):
        texto = ('[{"index":137,"name":"alsa_card.platform-sound","active_profile":"HiFi (Mic, Speaker)",'
                 '"profiles":{"Voice Call (Bluetooth)":{"priority":4050,"available":true}},'
                 '"properties":{"object.id":"68"}},'
                 '{"index":200,"name":"bluez_card.00_11","active_profile":"a2dp-sink",'
                 '"profiles":{"headset-head-unit-cvsd":{"available":false}},'
                 '"properties":{"object.id":"91"}}]')
        t = S.parse_tarjetas(texto)
        self.assertEqual(t["movil"]["id"], 68)
        self.assertTrue(t["movil"]["perfiles"][S.P_MOVIL_BT])
        self.assertEqual(t["casco"]["id"], 91)
        self.assertFalse(t["casco"]["perfiles"][S.P_CASCO_VOZ])




class Enrutado(unittest.TestCase):
    """La comprobacion y reparacion del enrutado tras colgar (2026-09-18).

    El cambio de perfil de la llamada puede dejar a wireplumber sin enlazar
    ningun flujo nuevo; entonces el movil se queda sin avisos, sin timbre y la
    llamada siguiente sale muda. Aqui se comprueba que se detecta, que se repara
    colgado y que NO se toca nada con una llamada en curso.
    """

    def setUp(self):
        import tempfile
        self.tmp = tempfile.mkdtemp()
        self._silencio, S.SILENCIO = S.SILENCIO, os.path.join(self.tmp, "silencio.wav")
        self._actas, S.ACTAS = S.ACTAS, os.path.join(self.tmp, "llamadas.log")

    def tearDown(self):
        S.SILENCIO, S.ACTAS = self._silencio, self._actas

    def _sistema(self, rc_paplay):
        sis = S.Sistema.__new__(S.Sistema)
        sis.hechos = []

        def _cmd(args, plazo=4):
            sis.hechos.append(args[0])
            if args[0] == "paplay":
                return rc_paplay, "", "Stream error: Timeout" if rc_paplay else ""
            return 0, "", ""
        sis._cmd = _cmd
        return sis

    def test_crea_el_silencio_y_lo_reproduce(self):
        sis = self._sistema(0)
        self.assertTrue(sis.enrutado_vivo())
        self.assertTrue(os.path.exists(S.SILENCIO))
        # cabecera WAV de verdad, 0,2 s estereo a 48 kHz
        with open(S.SILENCIO, "rb") as f:
            cab = f.read(12)
        self.assertEqual(cab[:4], b"RIFF")
        self.assertEqual(cab[8:12], b"WAVE")
        self.assertEqual(os.path.getsize(S.SILENCIO), 44 + 9600 * 4)

    def test_paplay_que_expira_es_enrutado_roto(self):
        self.assertFalse(self._sistema(1).enrutado_vivo())

    def _supervisor(self, sis, en_llamada=False):
        sup = S.Supervisor.__new__(S.Supervisor)
        sup.sis = sis
        sup.en_llamada = en_llamada
        sup.acta = S.Acta(sis, ruta=S.ACTAS)
        return sup

    def test_enrutado_sano_no_reinicia_nada(self):
        sis = self._sistema(0)
        self._supervisor(sis)._reparar_enrutado()
        self.assertNotIn("systemctl", sis.hechos)

    def test_enrutado_roto_reinicia_wireplumber_y_deja_constancia(self):
        sis = self._sistema(1)
        self._supervisor(sis)._reparar_enrutado()
        self.assertIn("systemctl", sis.hechos)
        with open(S.ACTAS) as f:
            acta = f.read()
        self.assertIn("ENRUTADO ROTO", acta)

    def test_con_llamada_en_curso_no_se_toca_wireplumber(self):
        sis = self._sistema(1)
        self._supervisor(sis, en_llamada=True)._reparar_enrutado()
        self.assertEqual(sis.hechos, [])


class EsperarConComprobacionColgada(Base):
    """21-09 13:42: una consulta a pactl colgada 4 s no puede comerse todo el plazo de un paso."""

    def _cond(self, cuelgues, resultado_final):
        """cond() que se cuelga los segundos de `cuelgues` (uno por llamada) y luego da resultado_final."""
        cola = list(cuelgues)

        def cond():
            if cola:
                self.reloj.t += cola.pop(0)
                return False
            return resultado_final
        return cond

    def test_colgada_una_vez_y_luego_ve_el_cambio_da_exito(self):
        # antes: los 4 s colgada agotaban el plazo de 4 s -> False aunque la tarjeta ya estaba
        self.assertTrue(self.sup._esperar(self._cond([4.0], True), 4))

    def test_colgada_siempre_se_rinde_en_el_tope(self):
        t0 = self.reloj.t
        self.assertFalse(self.sup._esperar(self._cond([4.0] * 50, True), 4))
        self.assertLessEqual(self.reloj.t - t0, 3 * 4 + 4.0 + 0.25)   # tope 3×plazo (+ la última consulta)

    def test_sin_cuelgues_se_comporta_como_antes(self):
        t0 = self.reloj.t
        self.assertFalse(self.sup._esperar(lambda: False, 4))
        self.assertAlmostEqual(self.reloj.t - t0, 4.0, delta=0.26)


class ActaFallosResueltos(unittest.TestCase):
    """Un fallo que se repara durante la llamada no es un fallo de la llamada (2026-09-18).

    Con el casco, entrar SIN SCO es lo normal -- llega en a2dp-sink y el supervisor
    monta el enlace en ~2 s -- asi que toda llamada con casco cerraba «CON 1 FALLO(S)»
    aunque fuera perfecta, incluida la primera que el usuario dio por buena.
    """

    CAMPOS = dict(perfil="Voice Call (Bluetooth)", casco="headset-head-unit-cvsd",
                  auricular=None, altavoz=None, bajada_i2s=False, subida_micro=False,
                  bajada_bt=True, subida_bt=True, mute_micro=True, volumen=6,
                  calibracion=1, pcm_voz=True, cad_modo="CALL_AUDIO_MODE_CALL",
                  cad_altavoz=False, cad_mudo=False)

    def setUp(self):
        import tempfile
        self.tmp = tempfile.mkdtemp()
        self._actas, S.ACTAS = S.ACTAS, os.path.join(self.tmp, "llamadas.log")

    def tearDown(self):
        S.ACTAS = self._actas

    def _acta(self, scos):
        """Acta cuyo foto() devuelve una foto por pasada, con el SCO dado (la ultima se repite)."""
        fotos = [dict(self.CAMPOS, sco=s) for s in scos]
        reloj = iter(range(100))
        acta = S.Acta(S.Sistema.__new__(S.Sistema), reloj=lambda: next(reloj), ruta=S.ACTAS)
        caja = {"i": 0}

        def foto(t):
            f = fotos[min(caja["i"], len(fotos) - 1)]
            caja["i"] += 1
            return f
        acta.foto = foto
        return acta

    def _texto(self):
        with open(S.ACTAS) as f:
            return f.read()

    def test_el_sco_que_sube_durante_la_llamada_deja_de_ser_fallo(self):
        acta = self._acta([False, True, True])
        acta.abrir(None, True)
        self.assertEqual(acta.fallos, ["perfil Bluetooth sin enlace SCO en pie"])
        acta.pasada(None)
        self.assertEqual(acta.fallos, [])
        self.assertEqual(acta.resueltos, ["perfil Bluetooth sin enlace SCO en pie"])
        acta.cerrar(None)
        texto = self._texto()
        self.assertIn("OK (1 reparado(s) sobre la marcha)", texto)
        self.assertIn("✅ resuelto: perfil Bluetooth sin enlace SCO en pie", texto)
        self.assertIn("REPARADOS:", texto)
        self.assertNotIn("FALLOS:", texto)

    def test_casco_conectado_a_mitad_consta_en_el_acta(self):
        acta = self._acta([False])
        sin_casco = dict(self.CAMPOS, perfil="Voice Call (Earpiece)", casco=None, sco=False,
                         auricular=True, altavoz=False, bajada_i2s=True, subida_micro=True,
                         bajada_bt=False, subida_bt=False)
        con_casco = dict(self.CAMPOS, sco=True)
        fotos = [sin_casco, con_casco, con_casco]
        caja = {"i": 0}

        def foto(t):
            f = fotos[min(caja["i"], len(fotos) - 1)]
            caja["i"] += 1
            return f
        acta.foto = foto
        acta.abrir(None, False)
        acta.pasada(None)
        acta.cerrar(None)
        self.assertIn("probado: casco (conectado a mitad de llamada)", self._texto())

    def test_el_sco_que_nunca_sube_si_es_fallo(self):
        acta = self._acta([False, False, False])
        acta.abrir(None, True)
        acta.pasada(None)
        acta.cerrar(None)
        texto = self._texto()
        self.assertIn("CON 1 FALLO(S)", texto)
        self.assertIn("FALLOS: perfil Bluetooth sin enlace SCO en pie", texto)
        self.assertNotIn("REPARADOS:", texto)


if __name__ == "__main__":
    unittest.main()
