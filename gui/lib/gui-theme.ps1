# gui/lib/gui-theme.ps1 - ResourceDictionary WPF con la paleta y estilos STI.
# Tokens exactos de la guia interna de marca (no versionada en este repo). Cambiar un color = editar una linea aca.
function New-StiTheme {
@'
<Window.Resources>
  <SolidColorBrush x:Key="StiVerde"      Color="#43C961"/>
  <SolidColorBrush x:Key="StiVerdeDeep"  Color="#053028"/>
  <SolidColorBrush x:Key="StiVerdeClaro" Color="#5fd47f"/>
  <SolidColorBrush x:Key="StiBody"       Color="#0a1712"/>
  <SolidColorBrush x:Key="StiWindow"     Color="#0e1a15"/>
  <SolidColorBrush x:Key="StiCard"       Color="#13241c"/>
  <SolidColorBrush x:Key="StiChipBg"     Color="#11352a"/>
  <SolidColorBrush x:Key="StiChipBar"    Color="#0b2a21"/>
  <SolidColorBrush x:Key="StiInput"      Color="#0c1c15"/>
  <SolidColorBrush x:Key="StiBorde"      Color="#294a3b"/>
  <SolidColorBrush x:Key="StiBordeSutil" Color="#1d3e31"/>
  <SolidColorBrush x:Key="StiTexto"      Color="#eaf2ec"/>
  <SolidColorBrush x:Key="StiTexto2"     Color="#9cc3b2"/>
  <SolidColorBrush x:Key="StiTexto3"     Color="#7fb89e"/>
  <SolidColorBrush x:Key="StiTenue"      Color="#6fb597"/>
  <SolidColorBrush x:Key="StiAmbar"      Color="#e0a93a"/>
  <SolidColorBrush x:Key="StiNaranja"    Color="#E07820"/>
  <SolidColorBrush x:Key="StiRojo"       Color="#F05754"/>
  <SolidColorBrush x:Key="StiNa"         Color="#6a8a7b"/>

  <Style x:Key="StiLabel" TargetType="TextBlock">
    <Setter Property="Foreground" Value="{StaticResource StiTexto3}"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="10"/>
    <Setter Property="FontWeight" Value="600"/>
  </Style>

  <Style x:Key="StiSecHeader" TargetType="TextBlock">
    <Setter Property="Foreground" Value="{StaticResource StiTenue}"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="11"/>
    <Setter Property="FontWeight" Value="700"/>
    <Setter Property="Margin" Value="0,12,0,6"/>
  </Style>

  <Style x:Key="StiGrupoHeader" TargetType="TextBlock">
    <Setter Property="Foreground" Value="{StaticResource StiTenue}"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="11"/>
    <Setter Property="FontWeight" Value="700"/>
    <Setter Property="Margin" Value="0,14,0,9"/>
  </Style>

  <Style x:Key="StiCardExpander" TargetType="Expander">
    <Setter Property="Background" Value="{StaticResource StiCard}"/>
    <Setter Property="BorderBrush" Value="{StaticResource StiBorde}"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Foreground" Value="{StaticResource StiTexto}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Expander">
          <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10">
            <DockPanel>
              <ToggleButton x:Name="tb" DockPanel.Dock="Top" Cursor="Hand"
                            IsChecked="{Binding IsExpanded, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border Background="Transparent" Padding="14,11">
                      <Grid>
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <ContentPresenter Grid.Column="0" VerticalAlignment="Center"/>
                        <Path x:Name="arr" Grid.Column="1" VerticalAlignment="Center" Margin="10,0,0,0"
                              Data="M0,0 L8,8 L16,0" Stroke="#6fb597" StrokeThickness="2" Fill="Transparent"
                              RenderTransformOrigin="0.5,0.5"/>
                      </Grid>
                    </Border>
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsChecked" Value="True">
                        <Setter TargetName="arr" Property="RenderTransform">
                          <Setter.Value><RotateTransform Angle="180"/></Setter.Value>
                        </Setter>
                      </Trigger>
                    </ControlTemplate.Triggers>
                  </ControlTemplate>
                </ToggleButton.Template>
                <ContentPresenter ContentSource="Header"/>
              </ToggleButton>
              <Border x:Name="body" DockPanel.Dock="Bottom" Padding="14,0,14,12" Visibility="Collapsed"
                      BorderBrush="{StaticResource StiBordeSutil}" BorderThickness="0,1,0,0">
                <ContentPresenter/>
              </Border>
            </DockPanel>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsExpanded" Value="True">
              <Setter TargetName="body" Property="Visibility" Value="Visible"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="StiInputBox" TargetType="TextBox">
    <Setter Property="Background" Value="{StaticResource StiInput}"/>
    <Setter Property="Foreground" Value="{StaticResource StiTexto}"/>
    <Setter Property="BorderBrush" Value="{StaticResource StiBorde}"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Padding" Value="6,4"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="12"/>
  </Style>

  <Style x:Key="StiInputMono" TargetType="TextBox" BasedOn="{StaticResource StiInputBox}">
    <Setter Property="FontFamily" Value="DM Mono, Consolas"/>
  </Style>

  <Style x:Key="StiBtnPrimary" TargetType="Button">
    <Setter Property="Background" Value="{StaticResource StiVerde}"/>
    <Setter Property="Foreground" Value="{StaticResource StiVerdeDeep}"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontWeight" Value="700"/>
    <Setter Property="FontSize" Value="13"/>
    <Setter Property="Padding" Value="10,8"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="Cursor" Value="Hand"/>
  </Style>

  <Style x:Key="StiChip" TargetType="RadioButton">
    <Setter Property="Foreground" Value="{StaticResource StiTexto2}"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="Margin" Value="3,0"/>
    <Setter Property="Padding" Value="13,5"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="RadioButton">
          <Border x:Name="chip" CornerRadius="20" Padding="{TemplateBinding Padding}"
                  Background="{StaticResource StiChipBg}" BorderBrush="{StaticResource StiBorde}" BorderThickness="1">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="chip" Property="Background" Value="{StaticResource StiVerde}"/>
              <Setter Property="Foreground" Value="{StaticResource StiVerdeDeep}"/>
              <Setter Property="FontWeight" Value="600"/>
              <Setter TargetName="chip" Property="Effect">
                <Setter.Value>
                  <DropShadowEffect Color="#43C961" BlurRadius="12" ShadowDepth="0" Opacity="0.45"/>
                </Setter.Value>
              </Setter>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <!-- ComboBox DEFAULT (sin x:Key: aplica a TODOS los ComboBox). WPF por default pinta el popup
       con colores de sistema (fondo blanco), lo que dejaba el contenido ilegible (texto claro sobre
       blanco). Aca se estila el ToggleButton, el item seleccionado y el Popup con la paleta STI. -->
  <Style x:Key="StiComboToggle" TargetType="ToggleButton">
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ToggleButton">
          <Border x:Name="cbBorder" Background="{StaticResource StiInput}" BorderBrush="{StaticResource StiBorde}"
                  BorderThickness="1" CornerRadius="4">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <Path x:Name="cbArrow" Grid.Column="1" Margin="0,0,8,0" VerticalAlignment="Center"
                    Data="M0,0 L4,4 L8,0 Z" Fill="#6fb597"/>
            </Grid>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="cbBorder" Property="BorderBrush" Value="{StaticResource StiVerde}"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="ComboBox">
    <Setter Property="Background" Value="{StaticResource StiInput}"/>
    <Setter Property="Foreground" Value="{StaticResource StiTexto}"/>
    <Setter Property="BorderBrush" Value="{StaticResource StiBorde}"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="Padding" Value="6,4"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ComboBox">
          <Grid>
            <ToggleButton x:Name="ToggleButton" Style="{StaticResource StiComboToggle}"
                          Focusable="False" ClickMode="Press"
                          IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}"/>
            <ContentPresenter x:Name="ContentSite" IsHitTestVisible="False" Margin="{TemplateBinding Padding}"
                              VerticalAlignment="Center" HorizontalAlignment="Left"
                              Content="{TemplateBinding SelectionBoxItem}"
                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"/>
            <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                   AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
              <Border x:Name="DropDownBorder" MinWidth="{TemplateBinding ActualWidth}"
                      MaxHeight="{TemplateBinding MaxDropDownHeight}"
                      Background="{StaticResource StiCard}" BorderBrush="{StaticResource StiBorde}"
                      BorderThickness="1" CornerRadius="4">
                <ScrollViewer SnapsToDevicePixels="True">
                  <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained"/>
                </ScrollViewer>
              </Border>
            </Popup>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property="IsEnabled" Value="False">
              <Setter Property="Foreground" Value="{StaticResource StiTexto3}"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="ComboBoxItem">
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Foreground" Value="{StaticResource StiTexto}"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="Padding" Value="8,5"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ComboBoxItem">
          <Border x:Name="itemBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}"
                  CornerRadius="3">
            <ContentPresenter/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="itemBorder" Property="Background" Value="{StaticResource StiChipBg}"/>
              <Setter Property="Foreground" Value="{StaticResource StiVerdeClaro}"/>
            </Trigger>
            <Trigger Property="IsSelected" Value="True">
              <Setter TargetName="itemBorder" Property="Background" Value="{StaticResource StiVerde}"/>
              <Setter Property="Foreground" Value="{StaticResource StiVerdeDeep}"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
</Window.Resources>
'@
}
